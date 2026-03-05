import SwiftUI

/// Privacy Policy view that loads content from the local bundled text file
struct PrivacyPolicyView: View {
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
        .navigationTitle("Privacy Policy")
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
    }

    private func loadLocalPolicy() {
        guard localPolicyText.isEmpty else { return }
        if let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            localPolicyText = text
        } else {
            localPolicyText = "Privacy policy is unavailable offline."
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
