package com.vocable.eyetracking

import com.vocable.eyetracking.models.LandmarkPoint
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class UpperFacePitchTest {
    @Test
    fun jawDropDoesNotChangePitchAndCompensationStaysAvailable() {
        val closed = face(chinY = 0.72f)
        val open = face(chinY = 0.88f)

        val iris = IrisGazeCalculator()
        assertTrue(iris.headPoseCompensationEnabled)
        val closedIris = iris.estimateHeadPose(closed)
        val openIris = iris.estimateHeadPose(open)
        assertEquals(closedIris.second, openIris.second, 0.001f)

        val eyeball = Eyeball3DGazeCalculator()
        assertTrue(eyeball.headPoseCompensationEnabled)
        val closedEye = eyeball.estimateHeadPose(closed, 640f, 480f)
        val openEye = eyeball.estimateHeadPose(open, 640f, 480f)
        assertEquals(closedEye.second, openEye.second, 0.001f)
    }

    private fun face(chinY: Float): List<LandmarkPoint> {
        val points = MutableList(478) { LandmarkPoint(0.5f, 0.5f, 0f) }
        points[1] = LandmarkPoint(0.50f, 0.50f, 0f)
        points[10] = LandmarkPoint(0.50f, 0.28f, 0f)
        points[33] = LandmarkPoint(0.40f, 0.40f, 0f)
        points[263] = LandmarkPoint(0.60f, 0.40f, 0f)
        points[152] = LandmarkPoint(0.50f, chinY, 0f)
        points[234] = LandmarkPoint(0.30f, 0.45f, 0f)
        points[454] = LandmarkPoint(0.70f, 0.45f, 0f)
        points[362] = LandmarkPoint(0.58f, 0.40f, 0f)
        return points
    }
}
