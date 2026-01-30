package com.switch2go.aac.utility

import com.switch2go.aac.utils.Switch2GOEnvironment
import org.koin.dsl.module


val vocableTestModule = module {
    single { getInMemoryVocableDatabase() }
    single<Switch2GOEnvironment> { VocableTestEnvironment() }
}
