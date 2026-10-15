import SwiftUI
import SwiftData
import UIKit

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }

            RadarView()
                .tabItem {
                    Label("Radar", systemImage: "dot.radiowaves.left.and.right")
                }

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .task {
            UIApplication.shared.registerForRemoteNotifications()
            await BookBuddyRefreshService.refresh(context: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .monitoringDeviceTokenUpdated)) { _ in
            Task { try? await MonitoringSubscriptionService.sync(context: modelContext) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .monitoringPreferencesChanged)) { _ in
            Task { try? await MonitoringSubscriptionService.sync(context: modelContext) }
        }
        .sheet(isPresented: Binding(get: { !hasCompletedOnboarding }, set: { if !$0 { hasCompletedOnboarding = true } })) {
            OnboardingView { hasCompletedOnboarding = true }
        }
    }
}

private struct OnboardingView: View {
    let finish: () -> Void
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image("BookBuddyMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .accessibilityLabel("Book Buddy dog with books")
                Text("Welcome to Book Buddy").font(.largeTitle.bold())
                Text("Keep your reading history, follow the authors and series you care about, and let Radar surface what’s next.")
                    .font(.title3).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    Label("Start by importing Goodreads or adding a book.", systemImage: "square.and.arrow.down")
                    Label("Follow a book, author, or series to add it to Radar.", systemImage: "eye")
                    Label("Set locations and public event sources in Settings.", systemImage: "mappin.and.ellipse")
                }.font(.body)
                Spacer()
                Button("Get Started", action: finish).buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }.padding().navigationBarTitleDisplayMode(.inline)
        }
    }
}
