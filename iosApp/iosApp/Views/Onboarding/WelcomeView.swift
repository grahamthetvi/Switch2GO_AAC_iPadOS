import SwiftUI

/// First-launch onboarding view that introduces the app and its features.
struct WelcomeView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    private let totalPages = 4

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    switchModePage.tag(1)
                    gettingStartedPage.tag(2)
                    readyPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page indicator and navigation
                VStack(spacing: 20) {
                    pageIndicator

                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button {
                                withAnimation { currentPage -= 1 }
                            } label: {
                                Text("Back")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(14)
                            }
                            .contentShape(Rectangle())
                        }

                        Button {
                            if currentPage < totalPages - 1 {
                                withAnimation { currentPage += 1 }
                            } else {
                                settings.hasSeenOnboarding = true
                                dismiss()
                            }
                        } label: {
                            Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(14)
                        }
                        .contentShape(Rectangle())
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        OnboardingPageView(
            icon: "bubble.left.and.bubble.right.fill",
            iconColor: .blue,
            title: "Welcome to Switch2GO",
            paragraphs: [
                "Switch2GO is an Augmentative and Alternative Communication (AAC) app designed for people with Cerebral Visual Impairment (CVI) and others who need accessible communication.",
                "Choose phrases from categories, then tap or select them to speak out loud. The app works with touch, eye gaze, and head tracking so you can use whatever works best for you.",
                "The interface uses high-contrast, customizable layouts with fewer symbols per page to reduce visual complexity."
            ]
        )
    }

    private var switchModePage: some View {
        OnboardingPageView(
            icon: "cable.connector",
            iconColor: .orange,
            title: "Switch Control (Coming Soon)",
            paragraphs: [
                "Switch control via USB (e.g. Tapio) is in development. In a future update you’ll be able to connect adaptive switches to your iPad and control the app without Bluetooth.",
                "For now, you can use touch, eye gaze, or head tracking. Open Settings → Selection Mode to choose your input method."
            ]
        )
    }

    private var gettingStartedPage: some View {
        OnboardingPageView(
            icon: "hand.tap.fill",
            iconColor: .green,
            title: "Getting Started",
            paragraphs: [
                "On the main screen you’ll see category tiles (e.g. General, Basic Needs). Tap a category to open its phrases, then tap a phrase to speak it. Use the back arrow to return to categories.",
                "To use eye gaze or head tracking: open Settings (gear icon, top right) → Selection Mode, and choose Face Tracking or Eye Gaze. Hold the iPad in landscape with the front camera facing you.",
                "To reduce clutter: go to Settings → Edit Categories & Phrases and set how many phrases show per page."
            ]
        )
    }

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("You can revisit this guide anytime from Settings → Show Welcome Guide. Use Settings → Troubleshooting if eye or head tracking isn’t working. Enjoy communicating with Switch2GO!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.blue : Color.secondary.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .animation(.easeInOut, value: currentPage)
            }
        }
    }
}

/// Reusable page layout for onboarding screens.
struct OnboardingPageView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let paragraphs: [String]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 70))
                .foregroundColor(iconColor)

            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 16) {
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    WelcomeView()
}
