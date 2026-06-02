import SwiftUI
import WebKit
import Combine

/// Chromeless YouTube playback via the IFrame Player API inside WKWebView.
struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String
    @ObservedObject var holder: YouTubePlayerHolder

    func makeCoordinator() -> Coordinator {
        Coordinator(holder: holder)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        config.userContentController.add(context.coordinator, name: "playback")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        holder.attach(webView: webView)
        webView.loadHTMLString(Self.playerHTML(videoId: videoId), baseURL: URL(string: "https://www.youtube.com"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        holder.attach(webView: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "playback")
        coordinator.holder.detach()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let holder: YouTubePlayerHolder

        init(holder: YouTubePlayerHolder) {
            self.holder = holder
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "playback",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            switch type {
            case "ended", "error":
                holder.onEnded?()
            default:
                break
            }
        }
    }

    private static func playerHTML(videoId: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
        html, body { margin:0; padding:0; background:#000; height:100%; overflow:hidden; }
        #player { position:absolute; inset:0; width:100%; height:100%; pointer-events:none; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script>
        var tag = document.createElement('script');
        tag.src = 'https://www.youtube.com/iframe_api';
        var firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
        window.mediaPlayer = null;
        function onYouTubeIframeAPIReady() {
          window.mediaPlayer = new YT.Player('player', {
            height: '100%',
            width: '100%',
            videoId: '\(videoId)',
            playerVars: {
              autoplay: 1,
              controls: 0,
              modestbranding: 1,
              rel: 0,
              playsinline: 1,
              fs: 0,
              disablekb: 1,
              iv_load_policy: 3
            },
            events: {
              onStateChange: function(event) {
                if (event.data === YT.PlayerState.ENDED) {
                  window.webkit.messageHandlers.playback.postMessage({ type: 'ended' });
                }
              },
              onError: function() {
                window.webkit.messageHandlers.playback.postMessage({ type: 'error' });
              }
            }
          });
        }
        </script>
        </body>
        </html>
        """
    }
}

/// Controls YouTube playback from the overlay coordinator.
final class YouTubePlayerHolder: ObservableObject {
    private weak var webView: WKWebView?
    var onEnded: (() -> Void)?

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    func detach() {
        webView?.loadHTMLString("", baseURL: nil)
        webView = nil
        onEnded = nil
    }

    func setPaused(_ paused: Bool) {
        let command = paused ? "pauseVideo" : "playVideo"
        webView?.evaluateJavaScript("window.mediaPlayer && window.mediaPlayer.\(command)();", completionHandler: nil)
    }

    func stop() {
        webView?.evaluateJavaScript("window.mediaPlayer && window.mediaPlayer.stopVideo();", completionHandler: nil)
    }
}
