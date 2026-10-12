import SwiftUI

/// Privacy Policy view that loads content from the local bundled text file
struct PrivacyPolicyView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @State private var localPolicyText = ""
    
    var body: some View {
        ScrollView {
            Text(localPolicyText)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            loadLocalPolicy()
        }
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle(Text(l10n: "Privacy Policy"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label(L("Home"), systemImage: "house.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L("Done")) {
                    dismiss()
                }
            }
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func loadLocalPolicy() {
        guard localPolicyText.isEmpty else { return }
        if let url = LocalizationHelper.localizedURL(forResource: "PrivacyPolicy", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            localPolicyText = text
        } else {
            localPolicyText = L("Privacy policy is unavailable offline.")
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
