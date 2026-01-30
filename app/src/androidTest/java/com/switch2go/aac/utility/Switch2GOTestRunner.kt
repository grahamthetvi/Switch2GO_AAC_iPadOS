package com.switch2go.aac.utility

import android.app.Application
import android.content.Context
import androidx.test.runner.AndroidJUnitRunner

class Switch2GOTestRunner: AndroidJUnitRunner() {
    override fun newApplication(
        cl: ClassLoader?,
        className: String?,
        context: Context?
    ): Application {
        return super.newApplication(cl, TestApplication::class.java.name, context)
    }
}