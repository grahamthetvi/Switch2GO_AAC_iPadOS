import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .home

    enum Tab {
        case home
        case keyboard
        case settings
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content based on selected tab
                switch selectedTab {
                case .home:
                    HomeView()
                case .keyboard:
                    KeyboardView()
                case .settings:
                    SettingsView()
                }

                // Eye tracking pointer overlay (when enabled)
                if appState.isEyeTrackingEnabled {
                    EyeTrackingPointerView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 40) {
                        TabButton(icon: "house.fill", title: "Home", isSelected: selectedTab == .home) {
                            selectedTab = .home
                        }
                        TabButton(icon: "keyboard", title: "Keyboard", isSelected: selectedTab == .keyboard) {
                            selectedTab = .keyboard
                        }
                        TabButton(icon: "gearshape.fill", title: "Settings", isSelected: selectedTab == .settings) {
                            selectedTab = .settings
                        }
                    }
                }
            }
        }
    }
}

struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .blue : .gray)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
