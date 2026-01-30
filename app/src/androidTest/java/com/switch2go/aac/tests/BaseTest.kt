package com.switch2go.aac.tests

import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.rule.GrantPermissionRule
import com.switch2go.aac.splash.SplashActivity
import com.switch2go.aac.utility.IdlingResourceTestRule
import com.switch2go.aac.utility.VocableKoinTestRule
import org.junit.Rule

open class BaseTest {

    @get:Rule(order = 0)
    val vocableKoinTestRule = VocableKoinTestRule()

    @get:Rule(order = 1)
    val idlingResourceTestRule = IdlingResourceTestRule()

    @get:Rule(order = 2)
    val activityRule = ActivityScenarioRule(SplashActivity::class.java)

    @get:Rule
    var mRuntimePermissionRule = GrantPermissionRule.grant(android.Manifest.permission.CAMERA)

}
