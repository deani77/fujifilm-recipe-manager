import AppKit
import SwiftUI
import UniformTypeIdentifiers
import RecipeCore

@MainActor
final class LibraryModel: ObservableObject {
    @Published private(set) var document = RecipeDocument()
    @Published private(set) var canSave = false
    @Published var selectedID: UUID?
    @Published var message: String?
    @Published var notice: String?
    let repository: LibraryRepository
    init() {
        let root: URL
        if let custom = ProcessInfo.processInfo.environment["RECIPE_MANAGER_LIBRARY_PATH"] {
            root = URL(fileURLWithPath: custom)
        } else {
            root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("FujifilmRecipeManager/library.json")
        }
        repository = LibraryRepository(url: root)
        reload()
    }
    func reload() {
        do {
            document = try repository.load()
            canSave = true
            if !document.recipes.contains(where: { $0.id == selectedID }) { selectedID = document.recipes.first?.id }
            notice = nil; message = nil
        } catch { canSave = false; message = error.localizedDescription }
    }
    @discardableResult func commit(_ candidate: RecipeDocument) -> Bool {
        guard canSave else { message = "Reload the library successfully before editing."; return false }
        do { try repository.save(candidate); document = candidate; message = nil; notice = "Saved locally"; return true }
        catch { message = error.localizedDescription; return false }
    }
    func save(_ recipe: Recipe) -> Bool {
        var candidate = document
        if let index = candidate.recipes.firstIndex(where: { $0.id == recipe.id }) { candidate.recipes[index] = recipe }
        else { candidate.recipes.append(recipe) }
        if commit(candidate) { selectedID = recipe.id; return true }; return false
    }
    func delete(_ id: UUID) {
        var candidate = document
        candidate.recipes.removeAll { $0.id == id }
        if commit(candidate) { selectedID = candidate.recipes.first?.id }
    }
    func importDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        panel.message = "Import a Recipe Manager JSON library. Existing recipe IDs will never be overwritten."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= RecipeDocument.maximumBytes else { throw LibraryError.tooLarge }
            let imported = try RecipeDocument(data: Data(contentsOf: url))
            let merged = try document.merging(imported)
            if commit(merged) {
                selectedID = imported.recipes.first?.id ?? selectedID
                notice = "Imported \(imported.recipes.count) recipe(s)"
            }
        } catch { message = error.localizedDescription }
    }
    func exportDocument(recipe: Recipe? = nil) {
        var output = document
        if let recipe { output.recipes = [recipe] }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = recipe == nil ? "Recipe Library.json" : "Recipe.json"
        panel.message = "This exports library recipes only. It is not a camera settings backup."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            // Avoid bypassing repository locking/backup rules through the export panel.
            guard url.standardizedFileURL.resolvingSymlinksInPath() != repository.url.standardizedFileURL.resolvingSymlinksInPath() else {
                throw LibraryError.invalid("choose an export location outside the live library file")
            }
            try output.encoded().write(to: url, options: .atomic)
            notice = "Exported locally"
        } catch { message = error.localizedDescription }
    }
}
