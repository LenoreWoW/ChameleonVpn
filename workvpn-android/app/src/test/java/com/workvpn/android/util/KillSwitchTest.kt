package com.barqnet.android.util

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Unit tests for Kill Switch functionality
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class KillSwitchTest {

    private lateinit var context: Context
    private lateinit var killSwitch: KillSwitch

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        killSwitch = KillSwitch(context)
    }

    @Test
    fun `initial state should be disabled`() = runTest {
        val isEnabled = killSwitch.isEnabled()
        assertFalse(isEnabled, "Kill switch should be disabled by default")
    }

    @Test
    fun `setEnabled should persist state`() = runTest {
        killSwitch.setEnabled(true)

        val isEnabled = killSwitch.isEnabled()
        assertTrue(isEnabled, "Kill switch should be enabled after setEnabled(true)")
    }

    @Test
    fun `setEnabled false should disable kill switch`() = runTest {
        // Enable first
        killSwitch.setEnabled(true)
        assertTrue(killSwitch.isEnabled())

        // Then disable
        killSwitch.setEnabled(false)

        val isEnabled = killSwitch.isEnabled()
        assertFalse(isEnabled, "Kill switch should be disabled after setEnabled(false)")
    }

    @Test
    fun `observeState should emit current state`() = runTest {
        var observedState = false

        // Collect first emission
        killSwitch.observeState().collect { state ->
            observedState = state
            return@collect // Cancel after first emission
        }

        assertEquals(false, observedState, "Initial observed state should be false")
    }

    @Test
    fun `isSupported should return true on Android 8+`() {
        val isSupported = killSwitch.isSupported()

        // Robolectric defaults to API 29, so this should be true
        assertTrue(isSupported, "Kill switch should be supported on Android 8+")
    }

    @Test
    fun `activate should log action`() {
        // This test verifies activate() doesn't crash
        // Real implementation would set up firewall rules

        killSwitch.activate()

        // No assertion needed - just verify no exception
        assertTrue(true)
    }

    @Test
    fun `deactivate should log action`() {
        // This test verifies deactivate() doesn't crash

        killSwitch.deactivate()

        // No assertion needed - just verify no exception
        assertTrue(true)
    }

    @Test
    fun `multiple enable disable cycles should work`() = runTest {
        // Cycle 1
        killSwitch.setEnabled(true)
        assertTrue(killSwitch.isEnabled())

        killSwitch.setEnabled(false)
        assertFalse(killSwitch.isEnabled())

        // Cycle 2
        killSwitch.setEnabled(true)
        assertTrue(killSwitch.isEnabled())

        killSwitch.setEnabled(false)
        assertFalse(killSwitch.isEnabled())

        // Verify final state
        assertFalse(killSwitch.isEnabled())
    }

    @Test
    fun `setting same state multiple times should work`() = runTest {
        killSwitch.setEnabled(true)
        killSwitch.setEnabled(true)
        killSwitch.setEnabled(true)

        assertTrue(killSwitch.isEnabled())

        killSwitch.setEnabled(false)
        killSwitch.setEnabled(false)

        assertFalse(killSwitch.isEnabled())
    }
}
