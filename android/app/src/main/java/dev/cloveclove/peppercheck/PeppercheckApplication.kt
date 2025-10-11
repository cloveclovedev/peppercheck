package dev.cloveclove.peppercheck

import android.app.Application
import dev.cloveclove.peppercheck.di.AppContainer

class PeppercheckApplication : Application() {
    lateinit var container: AppContainer

    override fun onCreate() {
        super.onCreate()
        // AppContainerを初期化する際に、ApplicationのContext経由でcontentResolverを渡す
        container = AppContainer(applicationContext.contentResolver)
    }
}