import SwiftUI

/// First-launch onboarding view that introduces the app and its features.
struct WelcomeView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    private let totalPages = 10

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    orientationPage.tag(1)
                    navigationPage.tag(2)
                    bodySelectionPage.tag(3)
                    imageToolPage.tag(4)
                    cviFriendlyPage.tag(5)
                    cviDisplayPage.tag(6)
                    phraseContentPage.tag(7)
                    switchModePage.tag(8)
                    readyPage.tag(9)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Page style TabView otherwise expands under sibling chrome.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

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
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(14)
                        }
                        .contentShape(Rectangle())
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
                .background(Color(UIColor.systemBackground))
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
                "Choose phrases organized into categories, then tap or select them to speak out loud. The app works with touch, eye gaze, head tracking, arm raises, hand gestures, and Bluetooth switch control — use whatever works best.",
                "Every phrase can be individually styled with custom colors, images, borders, and text sizes. You can also attach videos, audio, YouTube clips, or simple games, share phrase packs with teachers, and back up your whole board."
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
                "If the camera is upside down, eye and head tracking pause automatically and a message prompts you to rotate back. Touch, switches, arm raises, and hand gestures still work.",
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
                "To change your input method, open Settings (gear icon, top right) and go to Selection Mode. Choose Touch Only, Head Tracking, Eye Gaze, Arm Raise Selection, or Hand Gesture Selection.",
                "You can add, edit, reorder, and delete categories and phrases from Settings → Edit Categories & Phrases. Export a category as a phrase pack to share with others."
            ]
        )
    }

    private var bodySelectionPage: some View {
        OnboardingPageView(
            icon: "figure.wave",
            iconColor: .mint,
            title: "Arm Raise & Hand Gestures",
            paragraphs: [
                "Arm Raise Selection and Hand Gesture Selection are camera-based modes that work without moving a cursor — great when fine eye or head control is difficult.",
                "Arm Raise: raise your left arm to choose the left phrase, or your right arm for the right phrase. Hold the raise briefly until it registers.",
                "Hand Gesture: open then close your left hand (or close then open) for the left phrase, and use your right hand for the right phrase.",
                "Both modes require exactly 2 phrases on screen. Set Symbols per page to 2 under Settings → Categories Display → CVI Display Settings.",
                "Stand or sit where your upper body and hands are visible to the front camera. Good lighting helps. Touch and external switches still work alongside these modes."
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
                "Once you're happy with the result, download the image and assign it to your phrase. You can also open the Image Tool from Settings."
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
                "Use 2 symbols per page for Arm Raise and Hand Gesture selection — left phrase on the left, right phrase on the right.",
                "You can also assign a specific background color to each symbol position (e.g. red for top-left, blue for top-right). Consistent position colors help users learn where to look.",
                "Find these settings at: Settings → Categories Display → CVI Display Settings.",
                "Combined with per-phrase styling (black background, bold colored text, real images), these layout options create an interface optimized for users with visual impairments."
            ]
        )
    }

    private var phraseContentPage: some View {
        OnboardingPageView(
            icon: "sparkles.rectangle.stack.fill",
            iconColor: .indigo,
            title: "Phrase Packs, Media & Backup",
            paragraphs: [
                "Phrase Packs (.switch2go files) let teachers share whole categories by email, AirDrop, or Files. Import from Settings → Phrase Packs. Export from Edit Categories & Phrases → choose a category → Export Category.",
                "When a phrase is selected, you can play a short video (20 seconds or less), audio clip, YouTube video, or a built-in game. Media starts after a short delay so another phrase can be chosen first — adjust the delay in Settings → Timing & Sensitivity.",
                "Edit phrase content in Settings → Edit Categories & Phrases → Edit Style on any phrase.",
                "Backup & Restore saves all categories, phrases, images, and settings to a file on this iPad. Nothing is uploaded to the cloud. Find it under Settings → Backup & Restore.",
                "Send switch output: in the Phrase Style Editor, turn on “Send switch output” on a phrase to pulse a paired ESP32 and toggle a fan or light through a PowerLink. Set up the connection under Settings → Selection Mode → Switch Control."
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
                "Scan & Select uses two switches: one moves a highlight across phrases, one selects. Switch to Phrase uses two to four switches — each switch speaks one phrase on the page (matching your symbols-per-page setting).",
                "Customize scan speed, control mode, and key mapping under Settings → Selection Mode → Switch Control. Default keys 1–4 must match the ESP32 firmware.",
                "Environmental control: wire GPIO 26 on the ESP32 through a relay or optocoupler to a PowerLink jack. Connect ESP32 output in Switch Control, then enable “Send switch output” on the phrase that should toggle the device.",
                "Touch, eye gaze, head tracking, arm raises, and hand gestures still work when switches are enabled."
            ]
        )
    }

    private var readyPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.green)
                    .padding(.top, 24)

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

                Text("Our support website (under Settings) also lets you create custom phrase images: pick from Wikimedia or upload your own, then download a version with the background removed and a colored outline — great for making CVI-friendly symbols.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Extra space so the last lines aren't tucked under the page dots.
                Color.clear.frame(height: 24)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.visible)
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
                Image(systemName: icon)
                    .font(.system(size: 70))
                    .foregroundColor(iconColor)
                    .padding(.top, 30)

                Text(title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 16) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 32)

                // Keep the last paragraph clear of the page indicator chrome.
                Color.clear.frame(height: 24)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.visible)
    }
}

#Preview {
    WelcomeView()
}
