import SwiftUI
import RecipeCore

@main
struct RecipeManagerApp: App {
    @StateObject private var library = LibraryModel()
    var body: some Scene {
        WindowGroup("Fujifilm Recipe Manager") {
            LibraryView(model: library)
        }
    }
}

struct LibraryView: View {
    @ObservedObject var model: LibraryModel
    @State private var search = ""
    @State private var editing: Recipe?
    @State private var deleting: Recipe?
    @State private var showInspector = false
    private var selected: Recipe? { model.document.recipes.first { $0.id == model.selectedID } }
    private var filtered: [Recipe] {
        model.document.recipes.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0[text: "author"].localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $model.selectedID) {
                    ForEach(filtered) { recipe in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.name).font(.headline)
                            Text(recipe.parameters["filmSimulation"]?.displayText ?? "Simulation unspecified")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4).tag(recipe.id)
                    }
                }.searchable(text: $search, prompt: "Find a recipe or author")
                HStack {
                    Text("\(model.document.recipes.count) recipes").font(.caption)
                    Spacer()
                    Image(systemName: "internaldrive").foregroundStyle(.secondary)
                    Text("Offline library").font(.caption).foregroundStyle(.secondary)
                }.padding(12)
            }.navigationTitle("Recipes").navigationSplitViewColumnWidth(min: 230, ideal: 280)
        } detail: {
            if let selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selected.name).font(.largeTitle).bold()
                            Text(selected.parameters["filmSimulation"]?.displayText ?? "Film simulation unspecified")
                                .font(.title3).foregroundStyle(.secondary)
                        }
                        HStack {
                            Button("Edit", systemImage: "pencil") { editing = selected }
                            Button("Duplicate", systemImage: "plus.square.on.square") { _ = model.save(selected.duplicated()) }
                            Button("Export recipe", systemImage: "square.and.arrow.up") { model.exportDocument(recipe: selected) }
                            Spacer()
                            Button("Delete", systemImage: "trash", role: .destructive) { deleting = selected }
                        }.disabled(!model.canSave)
                        if !selected[text: "author"].isEmpty { LabeledContent("Author", value: selected[text: "author"]) }
                        if !selected[text: "source"].isEmpty { LabeledContent("Source", value: selected[text: "source"]) }
                        Divider()
                        Grid(alignment: .leading, horizontalSpacing: 36, verticalSpacing: 12) {
                            ForEach(RecipeParameter.all) { spec in
                                if let value = selected.parameters[spec.id] {
                                    GridRow { Text(spec.label).foregroundStyle(.secondary); Text(value.displayText) }
                                }
                            }
                        }
                        if !selected[text: "notes"].isEmpty {
                            Text("Notes").font(.headline)
                            Text(selected[text: "notes"])
                        }
                        Text("X-M5 · C1–C4 import tested on firmware 1.30. Sending recipes to the camera is unavailable.")
                            .font(.callout).foregroundStyle(.secondary)
                        Text("Recipe exports are not camera settings backups.").font(.caption).foregroundStyle(.secondary)
                    }.padding(32).frame(maxWidth: 820, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
                }.textSelection(.enabled)
            } else {
                ContentUnavailableView {
                    Label(model.canSave ? "Your recipe notebook" : "Library unavailable", systemImage: "camera.filters")
                } description: {
                    Text(model.canSave ? "Create a recipe or import a Recipe Manager JSON library. Everything stays on this Mac." : "Reload after resolving the file error. The existing library will not be overwritten.")
                } actions: {
                    if model.canSave { Button("Create recipe") { editing = Recipe() }.buttonStyle(.borderedProminent) }
                }
            }
        }
        .frame(minWidth: 950, minHeight: 650)
        .toolbar {
            Button("New recipe", systemImage: "plus") { editing = Recipe() }.disabled(!model.canSave)
            Menu("Library", systemImage: "folder") {
                Button("Import JSON…") { model.importDocument() }.disabled(!model.canSave)
                Button("Export library…") { model.exportDocument() }.disabled(!model.canSave)
                Divider()
                Button("Reload from disk") { model.reload() }
            }
            .accessibilityLabel("Library")
            .help("Import, export or reload your recipe library")
            Button("Camera inspector", systemImage: "camera") { showInspector = true }
        }
        .safeAreaInset(edge: .bottom) {
            if let notice = model.notice { Text(notice).font(.caption).foregroundStyle(.secondary).padding(8) }
        }
        .sheet(item: $editing) { recipe in RecipeEditor(recipe: recipe) { model.save($0) ? nil : model.message ?? "Unable to save the library." } }
        .sheet(isPresented: $showInspector) { InspectorView() }
        .alert("Library error", isPresented: Binding(get: { model.message != nil && editing == nil }, set: { if !$0 { model.message = nil } })) {
            Button("OK") { model.message = nil }
        } message: { Text(model.message ?? "") }
        .confirmationDialog("Delete \(deleting?.name ?? "recipe")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete recipe", role: .destructive) { if let recipe = deleting { model.delete(recipe.id) }; deleting = nil }
        } message: { Text("This removes the local library entry. It does not change your camera.") }
    }
}
