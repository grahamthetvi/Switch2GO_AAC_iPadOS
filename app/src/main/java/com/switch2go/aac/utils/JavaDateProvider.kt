package com.switch2go.aac.utils

class JavaDateProvider : DateProvider {
    override fun currentTimeMillis(): Long = System.currentTimeMillis()
}