import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var eventLocations: [EventLocationPreference]
    @Query private var eventSources: [EventSourcePreference]
    @State private var importing = false
    @State private var importData: Data?
    @State private var isPresentingImportOptions = false
    @State private var message: String?
    @State private var isPresentingHardcoverConnection = false
    @State private var isSyncing = false
    @State private var isHardcoverConnected = false
    @State private var isRecapGatewayConnected = false
    @State private var isPresentingRecapGatewayConnection = false
    @State private var isPresentingEventLocation = false
    @State private var isPresentingEventSource = false
    @State private var isPresentingMonitoringConnection = false
    @State private var isMonitoringConnected = false
    @State private var exportDocument: PersonalDataExport?
    @State private var isExporting = false
    @AppStorage(ReleaseNotificationPreferences.releaseRemindersEnabledKey) private var releaseRemindersEnabled = false

    private var bookBuddyEventSources: [EventSourcePreference] {
        eventSources.filter { $0.kind == .bookBuddy }
    }

    private var readerAddedEventSources: [EventSourcePreference] {
        eventSources.filter { $0.kind == .readerAdded }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading Services") {
                    if isHardcoverConnected {
                        Label("Hardcover Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Button {
                            syncHardcover()
                        } label: {
                            if isSyncing { Label("Syncing…", systemImage: "arrow.triangle.2.circlepath") } else { Label("Sync Hardcover", systemImage: "arrow.triangle.2.circlepath") }
                        }
                        .disabled(isSyncing)
                        Button("Disconnect Hardcover", role: .destructive) {
                            do {
                                try HardcoverCredentialsStore.shared.removeToken()
                                isHardcoverConnected = false
                            } catch {
                                message = error.localizedDescription
                            }
                        }
                    } else {
                        Button("Connect Hardcover") { isPresentingHardcoverConnection = true }
                        Text("Sync reading history from Hardcover. Your API token is kept only in this device’s secure storage.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Data") {
                    Button("Import Goodreads CSV") { importing = true }
                    Button("Export Personal Data") {
                        do { exportDocument = try PersonalDataExportService.makeExport(context: modelContext); isExporting = true }
                        catch { message = error.localizedDescription }
                    }
                    Text("Goodreads is used only for one-time imports.").font(.footnote)
                }

                Section("Release Reminders") {
                    Toggle("Release reminders", isOn: $releaseRemindersEnabled)
                    Text("Book Buddy schedules reminders around known release dates: about three months, one month, one week, and on release day.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Events Near You") {
                    Button("Add Event Location") { isPresentingEventLocation = true }
                    ForEach(eventLocations) { location in
                        HStack {
                            Toggle(location.name, isOn: Bindable(location).isEnabled)
                            Text("\(location.radiusMiles, format: .number.precision(.fractionLength(0))) mi").foregroundStyle(.secondary)
                        }
                    }.onDelete { offsets in
                        offsets.map { eventLocations[$0] }.forEach(modelContext.delete)
                        try? modelContext.save()
                    }
                    Text("Book Buddy uses your saved locations to narrow event results. Add more than one place if you regularly read or travel in different areas.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Book Buddy Event Sources") {
                    if bookBuddyEventSources.isEmpty {
                        ContentUnavailableView("No Built-In Sources Yet", systemImage: "building.2", description: Text("Book Buddy will add vetted bookstore, library, and festival sources here as the local catalog grows."))
                    } else {
                        ForEach(bookBuddyEventSources) { source in
                            HStack {
                                Toggle(source.name, isOn: Bindable(source).isEnabled)
                                Text(source.kind.label).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("Built-in sources are curated by Book Buddy. Events remain linked to their original source so you can check details directly.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Your Added Sources") {
                    if readerAddedEventSources.isEmpty {
                        Text("No additional sources. You can optionally add a trusted public calendar feed below.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(readerAddedEventSources) { source in
                        Toggle(source.name, isOn: Bindable(source).isEnabled)
                    }.onDelete { offsets in
                        offsets.map { readerAddedEventSources[$0] }.forEach(modelContext.delete)
                        try? modelContext.save()
                    }
                    Button("Add iCalendar Feed (Advanced)") { isPresentingEventSource = true }
                    Text("This is for a specific public iCalendar link you already trust. It is optional; Book Buddy keeps these separate from its built-in catalog. Events are matched to authors, series, and upcoming books you follow.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Background Monitoring") {
                    if isMonitoringConnected {
                        Label("Monitoring Worker Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        Button("Sync Monitoring Now") { Task { await syncMonitoring() } }
                        Button("Disconnect Monitoring Worker", role: .destructive) {
                            do { try MonitoringGatewayCredentialsStore.shared.remove(); isMonitoringConnected = false } catch { message = error.localizedDescription }
                        }
                    } else {
                        Button("Connect Monitoring Worker") { isPresentingMonitoringConnection = true }
                    }
                    Text("The worker stores only an anonymous device ID, push token, and the books, authors, and series you explicitly follow. Your library and reading notes stay on this iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("AI Recaps") {
                    if isRecapGatewayConnected {
                        Label("Recap Gateway Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Button("Disconnect Recap Gateway", role: .destructive) {
                            do {
                                try RecapGatewayCredentialsStore.shared.removeConfiguration()
                                isRecapGatewayConnected = false
                            } catch {
                                message = error.localizedDescription
                            }
                        }
                    } else {
                        Button("Connect Recap Gateway") { isPresentingRecapGatewayConnection = true }
                        Text("Your Worker URL is public, but its app access token is kept only in this device’s secure storage. Book Buddy never stores your OpenAI API key.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    importData = try Data(contentsOf: url)
                    isPresentingImportOptions = true
                } catch {
                    message = error.localizedDescription
                }
            }
            .fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .json, defaultFilename: "BookBuddy-Export") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .alert("Goodreads Import", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
            .sheet(isPresented: $isPresentingHardcoverConnection) {
                HardcoverConnectionView { connected in
                    isHardcoverConnected = connected
                    if connected { syncHardcover() }
                }
            }
            .sheet(isPresented: $isPresentingImportOptions) {
                if let importData {
                    GoodreadsImportOptionsView(data: importData) { filter in
                        do {
                            let result = try GoodreadsImporter().import(importData, context: modelContext, filter: filter)
                            message = "Imported \(result.imported) books; updated \(result.updated); skipped \(result.skipped)."
                        } catch {
                            message = error.localizedDescription
                        }
                    }
                }
            }
            .sheet(isPresented: $isPresentingRecapGatewayConnection) {
                RecapGatewayConnectionView { connected in
                    isRecapGatewayConnected = connected
                }
            }
            .sheet(isPresented: $isPresentingEventLocation) { EventLocationEditor { location in modelContext.insert(location); try? modelContext.save() } }
            .sheet(isPresented: $isPresentingEventSource) { EventSourceEditor { source in modelContext.insert(source); try? modelContext.save() } }
            .sheet(isPresented: $isPresentingMonitoringConnection) {
                MonitoringConnectionView { connected in isMonitoringConnected = connected; if connected { Task { await syncMonitoring() } } }
            }
            .task {
                refreshHardcoverConnection()
                refreshRecapGatewayConnection()
                isMonitoringConnected = (try? MonitoringGatewayCredentialsStore.shared.configuration()) != nil
            }
            .onChange(of: releaseRemindersEnabled) { _, enabled in
                Task { await updateReleaseReminderSetting(enabled: enabled) }
            }
        }
    }

    private func refreshHardcoverConnection() {
        isHardcoverConnected = (try? HardcoverCredentialsStore.shared.token()) != nil
    }

    private func refreshRecapGatewayConnection() {
        isRecapGatewayConnected = (try? RecapGatewayCredentialsStore.shared.configuration()) != nil
    }

    private func syncHardcover() {
        Task {
            isSyncing = true
            defer { isSyncing = false }
            do {
                guard let token = try HardcoverCredentialsStore.shared.token(), !token.isEmpty else {
                    throw ReadingDataProviderError.notConnected
                }
                let result = try await ReadingSyncService.sync(from: HardcoverProvider(token: token), context: modelContext)
                message = "Hardcover sync complete: \(result.imported) added, \(result.updated) updated, \(result.preservedLocalRecords) local records preserved."
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func updateReleaseReminderSetting(enabled: Bool) async {
        guard enabled else {
            await ReleaseNotificationService.rescheduleAll(context: modelContext)
            return
        }
        do {
            guard try await ReleaseNotificationService.requestAuthorization() else {
                releaseRemindersEnabled = false
                message = "Notifications are disabled. You can enable them in iPhone Settings."
                return
            }
            await ReleaseNotificationService.rescheduleAll(context: modelContext)
        } catch {
            releaseRemindersEnabled = false
            message = error.localizedDescription
        }
    }

    private func syncMonitoring() async {
        do { try await MonitoringSubscriptionService.sync(context: modelContext); message = "Monitoring preferences synced." }
        catch { message = error.localizedDescription }
    }

}

private struct GoodreadsImportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    let data: Data
    let importBooks: (GoodreadsImportFilter) -> Void
    @State private var usesDateFilter = false
    @State private var earliestActivityDate = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1)) ?? .now

    private var filter: GoodreadsImportFilter {
        GoodreadsImportFilter(earliestActivityDate: usesDateFilter ? earliestActivityDate : nil)
    }

    private var preview: (eligible: Int, skipped: Int) {
        (try? GoodreadsImporter().preview(data, filter: filter)) ?? (0, 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Only recent reading activity", isOn: $usesDateFilter)
                    if usesDateFilter {
                        DatePicker("On or after", selection: $earliestActivityDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Choose What to Import")
                } footer: {
                    Text("When enabled, a record is skipped only when its newest Goodreads Date Read or Date Added is before this date. Records with neither date stay included.")
                }

                Section("Import Preview") {
                    LabeledContent("Records to import", value: "\(preview.eligible)")
                    if usesDateFilter {
                        LabeledContent("Records to skip", value: "\(preview.skipped)")
                    }
                }
            }
            .navigationTitle("Goodreads Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import \(preview.eligible)") {
                        importBooks(filter)
                        dismiss()
                    }
                    .disabled(preview.eligible == 0)
                }
            }
        }
    }
}

private struct MonitoringConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var endpoint = ""
    @State private var token = ""
    @State private var errorMessage: String?
    let completion: (Bool) -> Void
    var body: some View {
        NavigationStack {
            Form {
                TextField("Worker endpoint", text: $endpoint).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                SecureField("Worker access token", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("Enter the URL ending in /v1/monitor/subscriptions. The access token stays in this device’s secure storage.").font(.footnote).foregroundStyle(.secondary)
            }.navigationTitle("Connect Monitoring").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Connect") { do { try MonitoringGatewayCredentialsStore.shared.save(MonitoringGatewayConfiguration(endpointString: endpoint, token: token)); completion(true); dismiss() } catch { errorMessage = error.localizedDescription } }.disabled(endpoint.isEmpty || token.isEmpty) }
                }
                .alert("Could Not Connect", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }
}

private struct EventLocationEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var radius = "25"
    let save: (EventLocationPreference) -> Void
    var body: some View {
        NavigationStack {
            Form {
                TextField("Location name", text: $name)
                TextField("Latitude", text: $latitude).keyboardType(.numbersAndPunctuation)
                TextField("Longitude", text: $longitude).keyboardType(.numbersAndPunctuation)
                TextField("Radius (miles)", text: $radius).keyboardType(.decimalPad)
                Text("Use coordinates from your preferred map app. Events without coordinates remain visible so you don’t miss them.").font(.footnote).foregroundStyle(.secondary)
            }.navigationTitle("Event Location").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { guard let lat = Double(latitude), let lon = Double(longitude) else { return }; save(EventLocationPreference(name: name, latitude: lat, longitude: lon, radiusMiles: Double(radius) ?? 25)); dismiss() }.disabled(name.isEmpty || Double(latitude) == nil || Double(longitude) == nil) }
                }
        }
    }
}

private struct EventSourceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var feedURL = ""
    let save: (EventSourcePreference) -> Void
    var body: some View {
        NavigationStack {
            Form {
                TextField("Source name", text: $name)
                TextField("Public iCalendar URL", text: $feedURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                Text("This must be a public calendar feed URL, usually ending in .ics.").font(.footnote).foregroundStyle(.secondary)
            }.navigationTitle("Event Source").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { guard URL(string: feedURL)?.scheme?.hasPrefix("http") == true else { return }; save(EventSourcePreference(name: name, feedURL: feedURL)); dismiss() }.disabled(name.isEmpty || URL(string: feedURL)?.scheme?.hasPrefix("http") != true) }
                }
        }
    }
}

private struct RecapGatewayConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var endpoint = ""
    @State private var token = ""
    @State private var errorMessage: String?
    let completion: (Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Worker endpoint", text: $endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("App access token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PasteButton(payloadType: String.self) { strings in
                        token = strings.first ?? ""
                    }
                } footer: {
                    Text("Enter the full URL ending in /v1/recaps and the CLIENT_TOKEN you generated during deployment. Do not enter your OpenAI API key here.")
                }
            }
            .navigationTitle("Connect Recap Gateway")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        do {
                            let configuration = try RecapGatewayConfiguration(endpointString: endpoint, token: token)
                            try RecapGatewayCredentialsStore.shared.save(configuration: configuration)
                            completion(true)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Could Not Connect", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

private struct HardcoverConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var errorMessage: String?
    let completion: (Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Hardcover API token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Find it in Hardcover: Account Settings → API. Book Buddy stores it in the iOS Keychain and uses it only for one-way sync.")
                }
            }
            .navigationTitle("Connect Hardcover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        do {
                            try HardcoverCredentialsStore.shared.save(token: token)
                            completion(true)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Could Not Connect", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}
