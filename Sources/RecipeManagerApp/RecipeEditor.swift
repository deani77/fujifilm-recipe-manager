import SwiftUI
import RecipeCore

struct RecipeEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var original: Recipe
    @State private var name: String
    @State private var author: String
    @State private var source: String
    @State private var notes: String
    @State private var values: [String: String]
    @State private var error: String?
    let onSave: (Recipe) -> String?

    init(recipe: Recipe, onSave: @escaping (Recipe) -> String?) {
        _original = State(initialValue: recipe)
        _name = State(initialValue: recipe.name)
        _author = State(initialValue: recipe[text: "author"])
        _source = State(initialValue: recipe[text: "source"])
        _notes = State(initialValue: recipe[text: "notes"])
        _values = State(initialValue: recipe.parameters.mapValues(\.displayText))
        self.onSave = onSave
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit recipe").font(.title2).bold()
            Text("Library values only · blank means unspecified · saving does not change the camera")
                .font(.caption).foregroundStyle(.secondary)
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Author", text: $author)
                    TextField("Source / attribution", text: $source)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                Section("Rendering settings") {
                    ForEach(RecipeParameter.all) { spec in
                        TextField(spec.label, text: Binding(get: { values[spec.id] ?? "" }, set: { values[spec.id] = $0 }))
                            .help(spec.hint)
                            .disabled(original.parameters[spec.id].map { !$0.isEditableScalar } ?? false)
                    }
                }
            }.formStyle(.grouped)
            if let error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Text("Unknown imported fields are preserved.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save recipe") { save() }.keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 660, height: 700)
    }
    private func save() {
        do {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LibraryError.invalid("name is required") }
            var recipe = original
            recipe.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            // Do not coerce unedited imported metadata of an unknown type into empty text.
            if author != original[text: "author"] { recipe[text: "author"] = author }
            if source != original[text: "source"] { recipe[text: "source"] = source }
            if notes != original[text: "notes"] { recipe[text: "notes"] = notes }
            for spec in RecipeParameter.all {
                let input = values[spec.id] ?? ""
                if input != (original.parameters[spec.id]?.displayText ?? "") {
                    recipe.parameters[spec.id] = try spec.parse(input)
                }
            }
            if let failure = onSave(recipe) { error = failure }
            else { dismiss() }
        } catch { self.error = error.localizedDescription }
    }
}
