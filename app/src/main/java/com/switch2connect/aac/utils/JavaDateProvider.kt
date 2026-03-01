package com.switch2connect.aac.utils

class JavaDateProvider : DateProvider {
    override fun currentTimeMillis(): Long = System.currentTimeMillis()
}