package com.switch2connect.aac.utility

import com.switch2connect.aac.utils.VocableEnvironment
import org.koin.dsl.module


val vocableTestModule = module {
    single { getInMemoryVocableDatabase() }
    single<VocableEnvironment> { VocableTestEnvironment() }
}
