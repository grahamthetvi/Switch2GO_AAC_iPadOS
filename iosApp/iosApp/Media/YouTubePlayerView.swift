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

        /// Errors where retrying or continuing is pointless (see YouTube IFrame API docs).
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
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>
        html, body { margin:0; padding:0; background:#000; height:100%; overflow:hidden; }
        #player { position:absolute; inset:0; width:100%; height:100%; pointer-events:none; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script>
        (function() {
          var ORIGIN = 'https://www.youtube.com';
          var startMuted = true;
          var unmuteAttempted = false;

          function post(type, extra) {
            var payload = Object.assign({ type: type }, extra || {});
            window.webkit.messageHandlers.playback.postMessage(payload);
          }

          function tryUnmute(player) {
            if (unmuteAttempted || !player || !player.unMute) return;
            unmuteAttempted = true;
            try { player.unMute(); } catch (e) {}
          }

          window.mediaPlayer = null;
          window.onYouTubeIframeAPIReady = function() {
            window.mediaPlayer = new YT.Player('player', {
              height: '100%',
              width: '100%',
              videoId: '\(videoId)',
              playerVars: {
                autoplay: 0,
                controls: 0,
                modestbranding: 1,
                rel: 0,
                playsinline: 1,
                fs: 0,
                disablekb: 1,
                iv_load_policy: 3,
                enablejsapi: 1,
                origin: ORIGIN,
                widget_referrer: ORIGIN + '/',
                mute: 1
              },
              events: {
                onReady: function(event) {
                  post('debug', { message: 'onReady' });
                  event.target.playVideo();
                },
                onStateChange: function(event) {
                  if (event.data === YT.PlayerState.PLAYING) {
                    if (startMuted) {
                      startMuted = false;
                      setTimeout(function() { tryUnmute(event.target); }, 250);
                    }
                  }
                  if (event.data === YT.PlayerState.ENDED) {
                    post('ended');
                  }
                },
                onAutoplayBlocked: function() {
                  post('debug', { message: 'onAutoplayBlocked — retrying muted' });
                  var p = window.mediaPlayer;
                  if (!p) return;
                  try {
                    p.mute();
                    p.playVideo();
                  } catch (e) {}
                },
                onError: function(event) {
                  post('error', { code: event.data });
                }
              }
            });
          };

          var tag = document.createElement('script');
          tag.src = 'https://www.youtube.com/iframe_api';
          var firstScriptTag = document.getElementsByTagName('script')[0];
          firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
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
            webView?.evaluateJavaScript(
                """
                (function() {
                  var p = window.mediaPlayer;
                  if (!p) return;
                  if (p.unMute) p.unMute();
                  p.playVideo();
                })();
                """,
                completionHandler: nil
            )
        }
    }

    func stop() {
        webView?.evaluateJavaScript("window.mediaPlayer && window.mediaPlayer.stopVideo();", completionHandler: nil)
    }
}
