import SwiftUI

/// First-launch onboarding view that introduces the app and its features.
struct WelcomeView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    private let totalPages = 8

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    orientationPage.tag(1)
                    navigationPage.tag(2)
                    imageToolPage.tag(3)
                    cviFriendlyPage.tag(4)
                    cviDisplayPage.tag(5)
                    switchModePage.tag(6)
                    readyPage.tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

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
                            Text(currentPage < totalPages - 1 ? "Next" : "I Agree — Get Started")
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
                "Choose phrases organized into categories, then tap or select them to speak out loud. The app works with touch, eye gaze, head tracking, and Bluetooth switch control — use whatever works best.",
                "The interface uses high-contrast, customizable layouts with fewer symbols per page to reduce visual complexity. Every phrase can be individually styled with custom colors, images, borders, and text sizes."
            ]
        )
    }

    private var orientationPage: some View {
        OnboardingPageView(
            icon: "ipad.landscape",
            iconColor: .orange,
            title: "iPad Orientation",
            paragraphs: [
                "You can use Switch2GO in almost any orientation. The only unsupported position is when the front camera is upside down.",
                "If the camera is upside down, eye and head tracking pause automatically and a message prompts you to rotate back. Touch and switch controls still work.",
                "Tip: If tracking seems off, rotate to a supported orientation and hold the iPad steady for a moment so tracking can recover."
            ]
        )
    }

    private var navigationPage: some View {
        OnboardingPageView(
            icon: "hand.tap.fill",
            iconColor: .green,
            title: "Navigating the App",
            paragraphs: [
                "The main screen shows category tiles (e.g. General, Basic Needs, Feelings). Tap a category to see its phrases, then tap a phrase to speak it out loud. Use the back arrow at the top to return to categories.",
                "Eye Gaze mode: keep your head as still as possible and move only your eyes. Look at a button and hold your gaze until the dwell ring completes to select it.",
                "Head Tracking mode: move your head in the direction you want the cursor to go. Moving your head left moves the cursor left, right moves right, up moves up, and down moves down.",
                "In both tracking modes, the blue cursor shows the current pointer location and the green progress ring fills while you dwell.",
                "To change your input method, open Settings (gear icon, top right) and go to Selection Mode. You can choose Touch Only, Face Tracking (head movements), or Eye Gaze.",
                "You can add, edit, reorder, and delete categories and phrases from Settings → Edit Categories & Phrases."
            ]
        )
    }

    private var imageToolPage: some View {
        OnboardingPageView(
            icon: "photo.fill.on.rectangle.fill",
            iconColor: .purple,
            title: "The Image Tool",
            paragraphs: [
                "When editing a phrase's image, you can open the Image Tool — a built-in web tool that helps you find and prepare the perfect picture for any phrase.",
                "Search Wikimedia Commons for thousands of free images — real photographs, not abstract icons — which are much better for users with CVI.",
                "The tool can automatically remove the background from any image, isolating just the subject. This makes the image cleaner and easier to recognize against your phrase's background color.",
                "You can also add a high-contrast colored outline around the object. Choose from colors like red, yellow, black, white, blue, green, and more, and adjust the outline thickness. This helps the subject stand out clearly.",
                "Once you're happy with the result, download the image and assign it to your phrase."
            ]
        )
    }

    private var cviFriendlyPage: some View {
        OnboardingPageView(
            icon: "eye.trianglebadge.exclamationmark",
            iconColor: .red,
            title: "Making CVI-Friendly Phrases",
            paragraphs: [
                "For users with Cortical Visual Impairment (CVI), how a phrase looks matters as much as what it says. Here are best practices for creating effective, high-visibility phrases:",
                "Use a BLACK background — dark backgrounds reduce visual clutter and help the foreground content stand out.",
                "Use RED or YELLOW text — these high-contrast colors are typically the easiest for CVI users to see. You can also make text bold and add a colored text border/outline for extra definition.",
                "Use REAL photographic images, not cartoon icons or abstract symbols. Real photos of familiar objects are much easier for CVI users to recognize. The Image Tool can help you find and prepare these.",
                "Keep it simple — show fewer symbols per page (2–4 is ideal). Go to Settings → Categories Display → CVI Display Settings to set symbol count and per-position colors.",
                "All of these options are available in the Phrase Style Editor when you edit any phrase in Settings → Edit Categories & Phrases."
            ]
        )
    }

    private var cviDisplayPage: some View {
        OnboardingPageView(
            icon: "square.grid.2x2.fill",
            iconColor: .teal,
            title: "CVI Display Settings",
            paragraphs: [
                "The CVI Display Settings let you control how many phrase symbols appear on each page. Fewer symbols means less visual clutter — choose between 2, 3, or 4 symbols per page.",
                "You can also assign a specific background color to each symbol position (e.g. red for top-left, blue for top-right). Consistent position colors help users learn where to look.",
                "Find these settings at: Settings → Categories Display → CVI Display Settings.",
                "Combined with per-phrase styling (black background, bold colored text, real images), these layout options create an interface optimized for users with visual impairments."
            ]
        )
    }

    private var switchModePage: some View {
        OnboardingPageView(
            icon: "antenna.radiowaves.left.and.right",
            iconColor: .orange,
            title: "Switch Control",
            paragraphs: [
                "Switch2GO works with the ESP32 Bluetooth switch interface (firmware in the ESP32 folder). Pair Switch2GO-XXXX in iPad Settings → Bluetooth, then enable Switch Control in the app.",
                "Scan & Select uses two switches: one moves a highlight across phrases, one selects. Switch to Phrase uses two to four switches — each switch speaks one phrase on the page.",
                "Enable switches under Settings → Selection Mode → Switch Control. Default keys 1–4 must match the ESP32 firmware.",
                "Touch, eye gaze, and head tracking still work when switches are enabled."
            ]
        )
    }

    private var readyPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.green)

                Text("Your Privacy Is Protected")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 16) {
                    privacyQuote("This app is designed with privacy as a core principle. We do not collect, store, or transmit any personal information from your device. All features operate entirely on your device, with no data sent to external servers.")

                    privacyQuote("We collect ZERO information. This app does not collect personal information, track usage analytics, send crash reports, connect to external servers, use cookies or tracking technologies, collect advertising identifiers, access your location, or store or transmit camera or microphone data.")

                    privacyQuote("No camera images, video, or eye tracking data is stored or transmitted. No audio recordings are stored or transmitted. All processing happens locally on your device.")

                    privacyQuote("We share NO data with anyone. This app uses no third-party services — no analytics platforms, no crash reporting, no advertising networks, no cloud services.")

                    privacyQuote("This app is safe for children and students of all ages. No data collection means compliance with COPPA, FERPA, and GDPR.")
                }
                .padding(.horizontal, 32)

                Text("Our support website (under Settings) also lets you create custom phrase images: pick from Wikimedia or upload your own, then download a version with the background removed and a colored outline—great for making CVI-friendly symbols.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer(minLength: 20)
            }
            .padding()
        }
    }

    private func privacyQuote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Color.green.opacity(0.6))
                .frame(width: 3)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
/// Content is placed inside a ScrollView so pages with many paragraphs
/// remain fully readable on smaller screens or in landscape.
struct OnboardingPageView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let paragraphs: [String]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 30)

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

                Spacer(minLength: 30)
            }
            .padding()
        }
    }
}

#Preview {
    WelcomeView()
}
