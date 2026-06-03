import SwiftUI
import WebKit
import Combine

/// Chromeless YouTube playback via a static embed iframe + postMessage (WKWebView-safe).
///
/// The IFrame Player API creates iframes dynamically; on iOS WKWebView that often omits the
/// Referer header YouTube now requires, which surfaces as error 152-4 / 153. A static iframe
/// with `referrerpolicy` and `enablejsapi=1` avoids that path.
struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String
    @ObservedObject var holder: YouTubePlayerHolder

    private static let embedHost = "https://www.youtube-nocookie.com"

    func makeCoordinator() -> Coordinator {
        Coordinator(holder: holder)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        config.userContentController.add(context.coordinator, name: "playback")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        holder.attach(webView: webView)

        let html = Self.playerHTML(videoId: videoId)
        let baseURL = URL(string: Self.embedHost)!
        webView.loadHTMLString(html, baseURL: baseURL)
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
            case "ended":
                holder.onEnded?()
            case "error":
                let code = body["code"] as? Int ?? -1
                DebugLog.error("YouTube player error \(code)", tag: "YouTube")
                if Self.isFatalYouTubeError(code) {
                    holder.onEnded?()
                }
            case "debug":
                if let message = body["message"] as? String {
                    DebugLog.debug(message, tag: "YouTube")
                }
            default:
                break
            }
        }

        private static func isFatalYouTubeError(_ code: Int) -> Bool {
            switch code {
            case 2, 5, 100, 101, 150, 153:
                return true
            default:
                return false
            }
        }
    }

    private static func playerHTML(videoId: String) -> String {
        let origin = embedHost
        let query = [
            "enablejsapi=1",
            "origin=\(origin)",
            "widget_referrer=\(origin)/",
            "autoplay=1",
            "mute=1",
            "playsinline=1",
            "controls=0",
            "modestbranding=1",
            "rel=0",
            "fs=0",
            "disablekb=1",
            "iv_load_policy=3",
        ].joined(separator: "&")
        let embedSrc = "\(embedHost)/embed/\(videoId)?\(query)"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <base href="\(origin)/">
        <style>
        html, body { margin:0; padding:0; background:#000; height:100%; overflow:hidden; }
        #yt { position:absolute; inset:0; width:100%; height:100%; border:0; }
        </style>
        </head>
        <body>
        <iframe
          id="yt"
          src="\(embedSrc)"
          referrerpolicy="strict-origin-when-cross-origin"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
          allowfullscreen
        ></iframe>
        <script>
        (function() {
          var EMBED_ORIGIN = '\(origin)';
          var audioWakeDone = false;
          var iframe = document.getElementById('yt');

          function post(type, extra) {
            var payload = Object.assign({ type: type }, extra || {});
            window.webkit.messageHandlers.playback.postMessage(payload);
          }

          function ytCommand(func, args) {
            if (!iframe || !iframe.contentWindow) return;
            var msg = JSON.stringify({ event: 'command', func: func, args: args || '' });
            iframe.contentWindow.postMessage(msg, EMBED_ORIGIN);
            iframe.contentWindow.postMessage(msg, 'https://www.youtube.com');
          }

          window.mediaPlayer = {
            playVideo: function() { ytCommand('playVideo'); },
            pauseVideo: function() { ytCommand('pauseVideo'); },
            stopVideo: function() { ytCommand('stopVideo'); },
            mute: function() { ytCommand('mute'); },
            unMute: function() { ytCommand('unMute'); },
            setVolume: function(level) { ytCommand('setVolume', String(level)); },
            ensureAudible: function() {
              ytCommand('unMute');
              ytCommand('setVolume', '100');
              ytCommand('playVideo');
            },
            /** iOS WKWebView keeps autoplay muted; pause then play restores audio. */
            pauseThenPlay: function() {
              ytCommand('pauseVideo');
              setTimeout(function() {
                ytCommand('unMute');
                ytCommand('setVolume', '100');
                ytCommand('playVideo');
              }, 200);
            }
          };

          function wakeAudioOnce() {
            if (audioWakeDone) return;
            audioWakeDone = true;
            window.mediaPlayer.pauseThenPlay();
          }

          function parseMessage(data) {
            if (typeof data === 'string') {
              try { return JSON.parse(data); } catch (e) { return null; }
            }
            return data;
          }

          function isYouTubeOrigin(origin) {
            return origin && (origin.indexOf('youtube.com') !== -1 || origin.indexOf('youtube-nocookie.com') !== -1);
          }

          window.addEventListener('message', function(e) {
            if (!isYouTubeOrigin(e.origin)) return;
            var data = parseMessage(e.data);
            if (!data || !data.event) return;

            if (data.event === 'onReady') {
              post('debug', { message: 'iframe onReady' });
              ytCommand('playVideo');
            }
            if (data.event === 'onStateChange') {
              if (data.info === 1) {
                wakeAudioOnce();
              }
              if (data.info === 0) {
                post('ended');
              }
            }
            if (data.event === 'onError') {
              post('error', { code: data.info });
            }
          });

          iframe.addEventListener('load', function() {
            post('debug', { message: 'iframe loaded' });
          });
        })();
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
        if paused {
            webView?.evaluateJavaScript("window.mediaPlayer && window.mediaPlayer.pauseVideo();", completionHandler: nil)
        } else {
            ensureAudible()
        }
    }

    /// Unmute and resume — matches the gaze pause/play path that restores audio.
    func ensureAudible() {
        webView?.evaluateJavaScript(
            "window.mediaPlayer && window.mediaPlayer.ensureAudible();",
            completionHandler: nil
        )
    }

    func stop() {
        webView?.evaluateJavaScript("window.mediaPlayer && window.mediaPlayer.stopVideo();", completionHandler: nil)
    }
}
