package com.switch2connect.aac.facetracking

import android.os.Bundle
import androidx.fragment.app.activityViewModels
import com.google.ar.core.AugmentedFace
import com.google.ar.core.Config
import com.google.ar.core.Session
import com.google.ar.sceneform.ux.ArFragment
import java.util.EnumSet

/**
 * Head-tracking fragment. Built on Sceneform 1.17.1, which is unmaintained.
 *
 * Migration plan (do NOT undertake without a real device regression pass):
 *  1. Replace [ArFragment] with a `GLSurfaceView`/`ArCoreApk.Session`-based implementation
 *     (e.g. the community `sceneview-android` library) so we keep ARCore semantics, OR
 *  2. Reuse the MediaPipe FaceLandmarker stack already in
 *     [com.switch2connect.aac.eyegazetracking.MediaPipeIrisGazeTracker] for head pose,
 *     removing the ARCore dependency entirely.
 *
 * Runtime availability is already gated in
 * [com.switch2connect.aac.utils.FaceTrackingManager.checkIsSupportedDevice]; users on
 * devices without ARCore support fall back to other input modes.
 */
class FaceTrackFragment : ArFragment() {

    private val viewModel: FaceTrackingViewModel by activityViewModels()

    override fun getSessionConfiguration(session: Session): Config {
        val config = Config(session)
        config.augmentedFaceMode = Config.AugmentedFaceMode.MESH3D
        return config
    }

    override fun getSessionFeatures(): Set<Session.Feature> {
        return EnumSet.of(Session.Feature.FRONT_CAMERA)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        viewModel.headTrackingEnabledLd.observe(this) {
            enableFaceTracking(it)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityCreated(savedInstanceState: Bundle?) {
        super.onActivityCreated(savedInstanceState)

        with(planeDiscoveryController) {
            hide()
            setInstructionView(null)
        }

        arSceneView.scene.addOnUpdateListener {
            viewModel.onSceneUpdate(arSceneView.session?.getAllTrackables(AugmentedFace::class.java))
        }

        viewModel.adjustedVector.observe(viewLifecycleOwner) {
            viewModel.onScreenPointAvailable(arSceneView.scene.camera.worldToScreenPoint(it))
        }
    }

    private fun enableFaceTracking(enable: Boolean) {
        if (enable) {
            arSceneView.resume()
        } else {
            arSceneView.pause()
            viewModel.onSceneUpdate(null)
        }
    }

    @Deprecated(
        "Permission requesting now handled by FaceTrackingManager",
        ReplaceWith("FaceTrackingManager")
    )
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) { }

}
