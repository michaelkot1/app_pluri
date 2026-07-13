import Foundation

/// Q12 allergy data — the common-allergen chips plus a wider searchable
/// pool for the "specific ones" search field (SPEC §3.2).
enum AllergenCatalog {
    /// Always-visible chips — the most common food allergies.
    static let common: [String] = [
        "Peanuts", "Tree nuts", "Milk/dairy", "Eggs", "Wheat/gluten",
        "Soy", "Fish", "Shellfish", "Sesame",
    ]

    /// A wider pool the search field filters into matching chips, for
    /// allergies not common enough to warrant a permanent chip.
    static let searchable: [String] = [
        "Corn", "Mustard", "Celery", "Sulfites", "Lupin", "Molluscs",
        "Kiwi", "Strawberry", "Coconut", "Sunflower seeds", "Poppy seeds",
        "Buckwheat", "Chickpeas", "Lentils", "Green peas", "Cinnamon",
        "Garlic", "Yeast", "Gelatin", "Latex-fruit syndrome",
    ]
}
