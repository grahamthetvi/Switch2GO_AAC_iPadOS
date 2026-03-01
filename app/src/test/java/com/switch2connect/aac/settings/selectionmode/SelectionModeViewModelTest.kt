package com.switch2connect.aac.settings.selectionmode

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import com.switch2connect.aac.MainDispatcherRule
import com.switch2connect.aac.getOrAwaitValue
import com.switch2connect.aac.utils.FakeEyeGazePermissions
import com.switch2connect.aac.utils.FakeFaceTrackingPermissions
import com.switch2connect.aac.utils.FakeVocableSharedPreferences
import com.switch2connect.aac.utils.IEyeGazePermissions
import com.switch2connect.aac.utils.IFaceTrackingPermissions
import com.switch2connect.aac.utils.IVocableSharedPreferences
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test


class SelectionModeViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    private fun createViewModel(
        faceTrackingPermissions: IFaceTrackingPermissions,
        eyeGazePermissions: IEyeGazePermissions = FakeEyeGazePermissions(false),
        sharedPrefs: IVocableSharedPreferences = FakeVocableSharedPreferences()
    ): SelectionModeViewModel {
        return SelectionModeViewModel(faceTrackingPermissions, eyeGazePermissions, sharedPrefs)
    }

    private fun createTrackingPermissions(headTrackingEnabled: Boolean): IFaceTrackingPermissions {
        return FakeFaceTrackingPermissions(headTrackingEnabled)
    }

    @Test
    fun `headTrackingEnabled true on init if head tracking Enabled`() = runTest {

        val viewModel = createViewModel(createTrackingPermissions(headTrackingEnabled = true))

        assertTrue(viewModel.headTrackingEnabled.getOrAwaitValue())
    }

    @Test
    fun `headTrackingEnabled false on init if head tracking disabled`() = runTest {

        val viewModel = createViewModel(createTrackingPermissions(headTrackingEnabled = false))

        assertFalse(viewModel.headTrackingEnabled.getOrAwaitValue())
    }

    @Test
    fun `requestHeadTracking() sets headTrackingEnabled to false`() = runTest {

        // Setting false so its not Requested on init
        val viewModel = createViewModel(createTrackingPermissions(headTrackingEnabled = false))

        assertFalse(viewModel.headTrackingEnabled.getOrAwaitValue())

        viewModel.requestHeadTracking()

        assertFalse(viewModel.headTrackingEnabled.getOrAwaitValue())
    }

    @Test
    fun `disableHeadTracking() sets headTrackingEnabled to false`() = runTest {

        // Setting true so its not Disabled on init
        val viewModel = createViewModel(createTrackingPermissions(headTrackingEnabled = true))

        assertTrue(viewModel.headTrackingEnabled.getOrAwaitValue())

        viewModel.disableHeadTracking()

        assertFalse(viewModel.headTrackingEnabled.getOrAwaitValue())
    }
}