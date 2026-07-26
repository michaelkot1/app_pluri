import Foundation
import HealthKit
import Observation
import os.log

/// HealthKit-backed live HR + active energy for the Workout Screen (M4-11).
/// Reads only while streaming; workout writes remain M4-13.
@MainActor
@Observable
final class LiveWorkoutHealthMetricsProvider: WorkoutHealthMetricsProviding {
    private(set) var isAuthorized = false
    private(set) var heartRateBPM: Double?
    private(set) var activeEnergyKilocalories: Double?

    private let store: HKHealthStore
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "WorkoutHealth")
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var energyQuery: HKObserverQuery?
    private var streamingStartedAt: Date?
    private var isStreaming = false

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }
        guard let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        else {
            isAuthorized = false
            return
        }

        // Share workouts for future M4-13 write; read HR + active energy for live display (#50f).
        let toShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let toRead: Set<HKObjectType> = [heartRate, activeEnergy]

        do {
            try await store.requestAuthorization(toShare: toShare, read: toRead)
            // Read auth is opaque; after a successful prompt we attempt streaming
            // and keep "—" until samples arrive (never scold).
            isAuthorized = true
        } catch {
            logger.error("HealthKit authorization failed: \(error.localizedDescription, privacy: .public)")
            isAuthorized = false
        }
    }

    func startStreaming() {
        guard HKHealthStore.isHealthDataAvailable(), isAuthorized else {
            heartRateBPM = nil
            activeEnergyKilocalories = nil
            return
        }
        stopStreamingQueries()
        isStreaming = true
        streamingStartedAt = .now
        startHeartRateQuery()
        startActiveEnergyQuery()
    }

    func stopStreaming() {
        stopStreamingQueries()
        isStreaming = false
        streamingStartedAt = nil
        heartRateBPM = nil
        activeEnergyKilocalories = nil
    }

    private func startHeartRateQuery() {
        guard let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let predicate = HKQuery.predicateForSamples(
            withStart: streamingStartedAt ?? .now,
            end: nil,
            options: .strictStartDate
        )
        let query = HKAnchoredObjectQuery(
            type: heartRate,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.applyHeartRateSamples(samples)
            }
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.applyHeartRateSamples(samples)
            }
        }
        heartRateQuery = query
        store.execute(query)
    }

    private func applyHeartRateSamples(_ samples: [HKSample]?) {
        guard isStreaming,
              let quantitySamples = samples as? [HKQuantitySample],
              let latest = quantitySamples.last
        else { return }
        heartRateBPM = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
    }

    private func startActiveEnergyQuery() {
        guard let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }
        let query = HKObserverQuery(sampleType: activeEnergy, predicate: nil) { [weak self] _, _, error in
            if let error {
                Task { @MainActor in
                    self?.logger.error(
                        "Active energy observer error: \(error.localizedDescription, privacy: .public)"
                    )
                }
                return
            }
            Task { @MainActor in
                await self?.refreshActiveEnergy()
            }
        }
        energyQuery = query
        store.execute(query)
        Task { await refreshActiveEnergy() }
    }

    private func refreshActiveEnergy() async {
        guard isStreaming,
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let start = streamingStartedAt
        else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: .now,
            options: .strictStartDate
        )
        do {
            let sum = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKQuantity?, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: activeEnergy,
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
            if let sum {
                activeEnergyKilocalories = sum.doubleValue(for: .kilocalorie())
            }
        } catch {
            logger.error("Active energy stats failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func stopStreamingQueries() {
        if let heartRateQuery {
            store.stop(heartRateQuery)
            self.heartRateQuery = nil
        }
        if let energyQuery {
            store.stop(energyQuery)
            self.energyQuery = nil
        }
    }
}
