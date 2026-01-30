package com.switch2go.aac.utility

import androidx.test.espresso.IdlingResource
import androidx.test.espresso.idling.CountingIdlingResource
import com.switch2go.aac.utils.IdlingResourceContainer

class IdlingResourceContainerTestingImpl(name: String): IdlingResourceContainer {

    private val countingIdlingResource = CountingIdlingResource(name)
    val idlingResource: IdlingResource = countingIdlingResource

    override fun increment() {
        countingIdlingResource.increment()
    }

    override fun decrement() {
        countingIdlingResource.decrement()
    }
}