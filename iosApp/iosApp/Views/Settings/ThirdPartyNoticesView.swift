import SwiftUI

/// Open-source and third-party license notices bundled with the app.
struct ThirdPartyNoticesView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @State private var noticesText = ""

    var body: some View {
        ScrollView {
            Text(noticesText)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            loadNotices()
        }
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Open-Source Licenses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label("Home", systemImage: "house.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func loadNotices() {
        guard noticesText.isEmpty else { return }
        if let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            noticesText = text
        } else {
            noticesText = "Open-source license notices are unavailable offline."
        }
    }
}

#Preview {
    NavigationStack {
        ThirdPartyNoticesView()
    }
}
