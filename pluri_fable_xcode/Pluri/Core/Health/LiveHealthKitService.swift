import Foundation
import HealthKit
import Observation
import os.log

/// HealthKit-backed Insights / Score *reads* (M5-02 / M5-18).
/// Requests read-only authorization for steps, sleep, heart rate, and active energy.
/// Never shares samples, never uploads — workout writes stay on `LiveWorkoutHealthWriter`.
/// Foreground `HKObserverQuery` refresh is optional (no background delivery entitlement).
@MainActor
@Observable
final class LiveHealthKitService: HealthKitReading {
    private(set) var authorizationStatus: HealthKitReadAuthorizationStatus = .notDetermined

    private let store: HKHealthStore
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "HealthKitReading")
    private var observerQueries: [HKObserverQuery] = []
    private var observerHandler: (@MainActor () -> Void)?
    private var coalesceTask: Task<Void, Never>?
    private let observerCoalesceDelay: Duration = .seconds(1)

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
        Task { await refreshAuthorizationStatus() }
    }

    func refreshAuthorizationStatus() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            stopObservingHealthChanges()
            return
        }
        guard let types = Self.readTypes else {
            authorizationStatus = .unavailable
            stopObservingHealthChanges()
            return
        }

        do {
            let requestStatus = try await store.statusForAuthorizationRequest(
                toShare: [],
                read: types
            )
            switch requestStatus {
            case .shouldRequest:
                // Preserve explicit denial from a failed prior request; otherwise not determined.
                if authorizationStatus != .denied {
                    authorizationStatus = .notDetermined
                }
            case .unnecessary:
                // Prompt already handled; Apple read auth stays opaque — treat as connected.
                if authorizationStatus != .denied {
                    authorizationStatus = .authorized
                }
            case .unknown:
                if authorizationStatus != .denied, authorizationStatus != .authorized {
                    authorizationStatus = .notDetermined
                }
            @unknown default:
                if authorizationStatus != .denied, authorizationStatus != .authorized {
                    authorizationStatus = .notDetermined
                }
            }
        } catch {
            logger.error(
                "HealthKit read status failed: \(error.localizedDescription, privacy: .public)"
            )
            if authorizationStatus != .authorized {
                authorizationStatus = .notDetermined
            }
        }

        if authorizationStatus != .authorized {
            stopObservingHealthChanges()
        }
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            stopObservingHealthChanges()
            return
        }
        guard let types = Self.readTypes else {
            authorizationStatus = .unavailable
            stopObservingHealthChanges()
            return
        }

        do {
            // Read-only — do not request workout share here (write path is separate).
            try await store.requestAuthorization(toShare: [], read: types)
            authorizationStatus = .authorized
        } catch {
            logger.error(
                "HealthKit read authorization failed: \(error.localizedDescription, privacy: .public)"
            )
            authorizationStatus = .denied
            stopObservingHealthChanges()
        }
    }

    func daySnapshot(for date: Date, calendar: Calendar) async -> HealthDaySnapshot {
        let dayStart = calendar.startOfDay(for: date)
        guard authorizationStatus == .authorized,
              HKHealthStore.isHealthDataAvailable(),
              let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
        else {
            return .empty(dayStart: dayStart)
        }

        async let steps = cumulativeSum(
            identifier: .stepCount,
            unit: .count(),
            start: dayStart,
            end: dayEnd
        )
        async let energy = cumulativeSum(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            start: dayStart,
            end: dayEnd
        )
        async let heartRate = averageQuantity(
            identifier: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            start: dayStart,
            end: dayEnd
        )
        async let sleep = sleepHours(start: dayStart, end: dayEnd, calendar: calendar)

        return HealthDaySnapshot(
            dayStart: dayStart,
            stepCount: await steps,
            sleepHours: await sleep,
            averageHeartRateBPM: await heartRate,
            activeEnergyKilocalories: await energy
        )
    }

    func dailyHistory(
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar
    ) async -> [HealthDaySnapshot] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start <= end else { return [] }

        var emptyDays: [HealthDaySnapshot] = []
        var cursor = start
        while cursor <= end {
            emptyDays.append(.empty(dayStart: cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        guard authorizationStatus == .authorized,
              HKHealthStore.isHealthDataAvailable(),
              let rangeEnd = calendar.date(byAdding: .day, value: 1, to: end)
        else {
            return emptyDays
        }

        async let stepsByDay = dailyCumulativeCollection(
            identifier: .stepCount,
            unit: .count(),
            start: start,
            end: rangeEnd,
            calendar: calendar
        )
        async let energyByDay = dailyCumulativeCollection(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            start: start,
            end: rangeEnd,
            calendar: calendar
        )
        async let heartByDay = dailyAverageCollection(
            identifier: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            start: start,
            end: rangeEnd,
            calendar: calendar
        )
        async let sleepByDay = dailySleepHours(
            start: start,
            end: rangeEnd,
            calendar: calendar
        )

        let steps = await stepsByDay
        let energy = await energyByDay
        let heart = await heartByDay
        let sleep = await sleepByDay

        return emptyDays.map { day in
            HealthDaySnapshot(
                dayStart: day.dayStart,
                stepCount: steps[day.dayStart],
                sleepHours: sleep[day.dayStart],
                averageHeartRateBPM: heart[day.dayStart],
                activeEnergyKilocalories: energy[day.dayStart]
            )
        }
    }

    // MARK: - Foreground observation (M5-18)

    func startObservingHealthChanges(onChange: @escaping @MainActor () -> Void) {
        stopObservingHealthChanges()
        guard authorizationStatus == .authorized,
              HKHealthStore.isHealthDataAvailable(),
              let types = Self.observableSampleTypes
        else {
            return
        }

        observerHandler = onChange
        for sampleType in types {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) {
                [weak self] _, completionHandler, error in
                guard let self else {
                    completionHandler()
                    return
                }
                if let error {
                    Task { @MainActor in
                        self.logger.error(
                            "HealthKit observer failed: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                    completionHandler()
                    return
                }
                Task { @MainActor in
                    self.scheduleCoalescedObserverCallback()
                }
                completionHandler()
            }
            observerQueries.append(query)
            store.execute(query)
        }
        logger.debug("Started foreground HealthKit observation for \(types.count, privacy: .public) types")
    }

    func stopObservingHealthChanges() {
        coalesceTask?.cancel()
        coalesceTask = nil
        for query in observerQueries {
            store.stop(query)
        }
        observerQueries.removeAll()
        observerHandler = nil
    }

    private func scheduleCoalescedObserverCallback() {
        coalesceTask?.cancel()
        coalesceTask = Task { @MainActor in
            try? await Task.sleep(for: observerCoalesceDelay)
            guard !Task.isCancelled else { return }
            observerHandler?()
        }
    }

    // MARK: - Types

    private static var readTypes: Set<HKObjectType>? {
        guard let steps = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else {
            return nil
        }
        return [steps, energy, heartRate, sleep]
    }

    /// Sample types watched by foreground `HKObserverQuery` (no background delivery).
    private static var observableSampleTypes: [HKSampleType]? {
        guard let steps = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else {
            return nil
        }
        return [steps, energy, heartRate, sleep]
    }

    // MARK: - Quantity helpers

    private func cumulativeSum(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        do {
            let sum = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKQuantity?, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, statistics, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: statistics?.sumQuantity())
                }
                store.execute(query)
            }
            guard let sum else { return nil }
            return sum.doubleValue(for: unit)
        } catch {
            logger.error(
                "Stats sum failed (\(identifier.rawValue, privacy: .public)): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func averageQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        do {
            let average = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKQuantity?, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate: predicate,
                    options: .discreteAverage
                ) { _, statistics, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: statistics?.averageQuantity())
                }
                store.execute(query)
            }
            guard let average else { return nil }
            return average.doubleValue(for: unit)
        } catch {
            logger.error(
                "Stats average failed (\(identifier.rawValue, privacy: .public)): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func dailyCumulativeCollection(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        calendar: Calendar
    ) async -> [Date: Double] {
        await dailyStatisticsCollection(
            identifier: identifier,
            options: .cumulativeSum,
            start: start,
            end: end,
            calendar: calendar
        ) { statistics in
            statistics.sumQuantity()?.doubleValue(for: unit)
        }
    }

    private func dailyAverageCollection(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        calendar: Calendar
    ) async -> [Date: Double] {
        await dailyStatisticsCollection(
            identifier: identifier,
            options: .discreteAverage,
            start: start,
            end: end,
            calendar: calendar
        ) { statistics in
            statistics.averageQuantity()?.doubleValue(for: unit)
        }
    }

    private func dailyStatisticsCollection(
        identifier: HKQuantityTypeIdentifier,
        options: HKStatisticsOptions,
        start: Date,
        end: Date,
        calendar: Calendar,
        value: @escaping (HKStatistics) -> Double?
    ) async -> [Date: Double] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return [:]
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        do {
            let collection = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatisticsCollection?, Error>) in
                let query = HKStatisticsCollectionQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate: predicate,
                    options: options,
                    anchorDate: start,
                    intervalComponents: DateComponents(day: 1)
                )
                query.initialResultsHandler = { _, statisticsCollection, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: statisticsCollection)
                }
                store.execute(query)
            }
            guard let collection else { return [:] }

            var result: [Date: Double] = [:]
            collection.enumerateStatistics(from: start, to: end) { statistics, _ in
                let dayStart = calendar.startOfDay(for: statistics.startDate)
                // `enumerateStatistics` end is exclusive of the final boundary day we requested.
                guard dayStart < end else { return }
                if let metric = value(statistics) {
                    result[dayStart] = metric
                }
            }
            return result
        } catch {
            logger.error(
                "Stats collection failed (\(identifier.rawValue, privacy: .public)): \(error.localizedDescription, privacy: .public)"
            )
            return [:]
        }
    }

    // MARK: - Sleep

    private func sleepHours(start: Date, end: Date, calendar: Calendar) async -> Double? {
        let hoursByDay = await dailySleepHours(start: start, end: end, calendar: calendar)
        let dayStart = calendar.startOfDay(for: start)
        return hoursByDay[dayStart]
    }

    private func dailySleepHours(
        start: Date,
        end: Date,
        calendar: Calendar
    ) async -> [Date: Double] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return [:]
        }
        // Include samples that may have started the previous evening but ended in-range.
        let queryStart = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(
            withStart: queryStart,
            end: end,
            options: .strictStartDate
        )
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, results, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
                }
                store.execute(query)
            }

            var secondsByDay: [Date: TimeInterval] = [:]
            for sample in samples where Self.isAsleep(sample) {
                // Attribute the full asleep sample to the calendar day it ends (morning wake),
                // including overnight minutes before midnight — do not clip to the day window.
                let dayStart = calendar.startOfDay(for: sample.endDate)
                guard dayStart >= start, dayStart < end else { continue }
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                guard duration > 0 else { continue }
                secondsByDay[dayStart, default: 0] += duration
            }

            return secondsByDay.mapValues { $0 / 3_600 }
        } catch {
            logger.error("Sleep query failed: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    private static func isAsleep(_ sample: HKCategorySample) -> Bool {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else {
            return false
        }
        switch value {
        case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM, .asleep:
            return true
        case .inBed, .awake:
            return false
        @unknown default:
            return false
        }
    }
}
