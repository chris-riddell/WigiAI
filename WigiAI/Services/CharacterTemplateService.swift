import Foundation
import OSLog

/// Service for loading and managing character templates from the app bundle
///
/// Character templates are pre-configured JSON files that provide ready-to-use
/// characters with personalities, habits, and reminders. Templates are loaded once
/// at initialization from the app's Resources folder.
class CharacterTemplateService {
    /// Shared singleton instance
    static let shared = CharacterTemplateService()

    /// All loaded character templates
    private var templates: [CharacterTemplate] = []

    /// Initializes the service and loads templates from the app bundle
    private init() {
        loadTemplates()
    }

    // MARK: - Template Loading

    /// Loads all character templates from the app bundle's Resources folder
    ///
    /// Scans for `.json` files in the Resources directory and attempts to decode
    /// each as a `CharacterTemplate`. Successfully loaded templates are sorted by
    /// category and name.
    private func loadTemplates() {
        // Load templates from Resources folder (where Xcode copies them)
        guard let resourcePath = Bundle.main.resourcePath else {
            LoggerService.app.error("❌ Could not access bundle resources")
            return
        }

        let templatesURL = URL(fileURLWithPath: resourcePath)

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: templatesURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            LoggerService.app.debug("📄 Found \(fileURLs.count) files in directory")

            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            LoggerService.app.debug("📋 Found \(jsonFiles.count) JSON files")

            for fileURL in jsonFiles {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let template = try JSONDecoder().decode(CharacterTemplate.self, from: data)
                    templates.append(template)
                    LoggerService.app.info("✅ Loaded template: \(template.name)")
                } catch {
                    LoggerService.app.error("❌ Failed to load template from \(fileURL.lastPathComponent): \(error)")
                }
            }

            // Sort templates by category, then by name
            templates.sort { lhs, rhs in
                if lhs.category == rhs.category {
                    return lhs.name < rhs.name
                }
                return lhs.category < rhs.category
            }

            LoggerService.app.info("✅ Loaded \(self.templates.count) character templates")
        } catch {
            LoggerService.app.error("❌ Failed to read CharacterTemplates directory: \(error)")
        }
    }

    // MARK: - Public API

    /// Retrieves all available character templates
    /// - Returns: Array of all loaded templates, sorted by category and name
    func getAllTemplates() -> [CharacterTemplate] {
        return templates
    }

    /// Retrieves templates filtered by category
    /// - Parameter category: Category to filter by (e.g., "Productivity", "Health")
    /// - Returns: Array of templates matching the specified category
    func getTemplates(for category: String) -> [CharacterTemplate] {
        return templates.filter { $0.category == category }
    }

    /// Retrieves all unique categories from loaded templates
    /// - Returns: Sorted array of category names
    func getCategories() -> [String] {
        return Array(Set(templates.map { $0.category })).sorted()
    }

    /// Retrieves a specific template by its unique identifier
    /// - Parameter id: Template ID to search for
    /// - Returns: The matching template, or `nil` if not found
    func getTemplate(byId id: String) -> CharacterTemplate? {
        return templates.first { $0.id == id }
    }

    /// Searches templates by name or description
    /// - Parameter query: Search query string (case-insensitive)
    /// - Returns: Array of templates matching the search query
    func searchTemplates(query: String) -> [CharacterTemplate] {
        let lowercaseQuery = query.lowercased()
        return templates.filter {
            $0.name.lowercased().contains(lowercaseQuery) ||
            $0.description.lowercased().contains(lowercaseQuery)
        }
    }

    /// Creates a fully-configured Character instance from a template
    /// - Parameter template: The template to convert
    /// - Returns: A new `Character` with all habits and reminders configured
    func createCharacter(from template: CharacterTemplate) -> Character {
        return template.toCharacter()
    }
}
