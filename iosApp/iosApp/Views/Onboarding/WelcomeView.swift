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
                "Switch2GO is an Augmentative and Alternative Communication (AAC) app designed for people who need accessible communication tools.",
                "It supports multiple input methods including eye gaze tracking, head tracking, touch, and switch control -- so everyone can communicate in the way that works best for them."
            ]
        )
    }

    private var switchModePage: some View {
        OnboardingPageView(
            icon: "keyboard.fill",
            iconColor: .purple,
            title: "Switch Control with Tapio",
            paragraphs: [
                "You can use switch mode with Tapio, a USB switch interface by Adaptive Tech Solutions. Simply connect Tapio to your iPad via USB and plug in your adaptive switches -- no Bluetooth pairing required.",
                "We have yet to implement an open-source alternative, but it is coming soon. Stay tuned for an Arduino-based option that will provide the same functionality."
            ]
        )
    }

    private var gettingStartedPage: some View {
        OnboardingPageView(
            icon: "hand.tap.fill",
            iconColor: .orange,
            title: "Getting Started",
            paragraphs: [
                "The app starts in touch mode by default. Tap phrase tiles to speak, and use the category tabs to navigate between different sets of phrases.",
                "To enable eye gaze or head tracking, open Settings (the gear icon in the top-right corner) and go to Selection Mode. You can switch between tracking modes at any time.",
                "For eye and head tracking, hold your iPad in landscape orientation with the front camera facing you."
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

            Text("You can revisit this guide anytime from Settings. If you run into trouble, check out the Troubleshooting section in Settings for tips on getting tracking working.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Our support website (under Settings) also lets you create custom phrase images: pick from Wikimedia or upload your own, then download a version with the background removed and a colored outline—great for making CVI-friendly symbols.")
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
