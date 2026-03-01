import SwiftUI
import WebKit

/// Privacy Policy web view
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @State private var showLocalPolicy = false
    @State private var localPolicyText = ""
    
    var body: some View {
        Group {
            if showLocalPolicy {
                ScrollView {
                    Text(localPolicyText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                WebView(
                    url: URL(string: "https://github.com/grahamthetvi/Switch2GO_AAC_iPadOS_OLD/blob/main/Privacy_Policy")!,
                    onFail: {
                        showLocalPolicy = true
                    }
                )
            }
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

/// WebKit WebView wrapper for SwiftUI
struct WebView: UIViewRepresentable {
    let url: URL
    let onFail: (() -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFail: onFail)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onFail: (() -> Void)?

        init(onFail: (() -> Void)?) {
            self.onFail = onFail
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onFail?()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onFail?()
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
