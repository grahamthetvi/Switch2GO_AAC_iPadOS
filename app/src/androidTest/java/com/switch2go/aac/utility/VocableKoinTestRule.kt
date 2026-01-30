package com.switch2go.aac.utility

import androidx.test.platform.app.InstrumentationRegistry
import com.switch2go.aac.utils.Switch2GOSharedPreferences
import com.switch2go.aac.vocableKoinModule
import org.junit.rules.TestWatcher
import org.junit.runner.Description
import org.koin.android.ext.koin.androidContext
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.module.Module

class VocableKoinTestRule(
    private vararg val additionalTestModules: Module
): TestWatcher() {
    override fun starting(description: Description?) {
        startKoin {
            androidContext(InstrumentationRegistry.getInstrumentation().targetContext.applicationContext)
            modules(
                vocableKoinModule +
                vocableTestModule +
                additionalTestModules.toList()
            )
        }.koin.apply {
            get<Switch2GOSharedPreferences>().clearAll()
        }
    }

    override fun finished(description: Description?) {
        stopKoin()
    }
}
