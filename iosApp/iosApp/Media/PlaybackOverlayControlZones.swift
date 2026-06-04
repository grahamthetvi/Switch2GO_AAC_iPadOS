import CoreGraphics

/// Gaze/touch hotspot regions for fullscreen media and game overlays.
enum PlaybackOverlayControlZones {
    static func containsCenter(_ point: CGPoint, in size: CGSize) -> Bool {
        centerFrame(in: size).contains(point)
    }

    static func containsExit(_ point: CGPoint, in size: CGSize, safeTop: CGFloat = 0) -> Bool {
        exitFrame(in: size, safeTop: safeTop).contains(point)
    }

    static func centerFrame(in size: CGSize) -> CGRect {
        CGRect(
            x: size.width * 0.35,
            y: size.height * 0.35,
            width: size.width * 0.3,
            height: size.height * 0.3
        )
    }

    static func exitFrame(in size: CGSize, safeTop: CGFloat = 0) -> CGRect {
        CGRect(
            x: 0,
            y: safeTop,
            width: size.width * 0.15,
            height: size.height * 0.15
        )
    }
}
