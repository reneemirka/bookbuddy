import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var importing = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form { Section("Data") { Button("Import Goodreads CSV") { importing = true }; Text("Goodreads is used only for one-time imports.").font(.footnote) } }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; let r = try GoodreadsImporter().import(Data(contentsOf: url), context: modelContext); message = "Imported \(r.imported) books; updated \(r.updated)." } catch { message = error.localizedDescription }
            }
            .alert("Goodreads Import", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
        }
    }
}
