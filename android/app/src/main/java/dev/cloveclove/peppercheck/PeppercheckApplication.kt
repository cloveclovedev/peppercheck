package dev.cloveclove.peppercheck

import android.app.Application
import dev.cloveclove.peppercheck.di.AppContainer
import com.stripe.android.PaymentConfiguration

class PeppercheckApplication : Application() {
    lateinit var container: AppContainer

    override fun onCreate() {
        super.onCreate()
        PaymentConfiguration.init(
            applicationContext,
            BuildConfig.STRIPE_PUBLISHABLE_KEY
        )
        // AppContainerを初期化する際に、ApplicationのContext経由でcontentResolverを渡す
        container = AppContainer(applicationContext.contentResolver)
    }
}

