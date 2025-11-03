import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.google.services)
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties().apply {
    if (!localPropertiesFile.exists()) {
        error("Missing local.properties. Please provide required configuration properties.")
    }
    localPropertiesFile.inputStream().use { stream ->
        load(stream)
    }
}

fun Properties.requireProperty(key: String): String =
    getProperty(key) ?: error("Missing \"$key\" in local.properties")

android {
    namespace = "dev.cloveclove.peppercheck"
    compileSdk = 35

    defaultConfig {
        applicationId = "dev.cloveclove.peppercheck"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${localProperties.requireProperty("SUPABASE_ANON_KEY")}\"")
        buildConfigField("String", "WEB_GOOGLE_CLIENT_ID", "\"${localProperties.requireProperty("WEB_GOOGLE_CLIENT_ID")}\"")
    }

    buildTypes {
        debug {
            val supabaseUrlDebug = localProperties.getProperty("SUPABASE_URL_DEBUG")
                ?: localProperties.requireProperty("SUPABASE_URL")
            val gatewayUrlDebug = localProperties.getProperty("GATEWAY_URL_DEBUG")
                ?: localProperties.requireProperty("GATEWAY_URL")
            val stripePublishableKeyDebug = localProperties.getProperty("STRIPE_PUBLISHABLE_KEY_DEBUG")
                ?: localProperties.requireProperty("STRIPE_PUBLISHABLE_KEY")
            buildConfigField("String", "SUPABASE_URL", "\"$supabaseUrlDebug\"")
            buildConfigField(
                "String",
                "GATEWAY_URL",
                "\"$gatewayUrlDebug\""
            )
            buildConfigField(
                "String",
                "STRIPE_PUBLISHABLE_KEY",
                "\"$stripePublishableKeyDebug\""
            )
        }
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            buildConfigField(
                "String",
                "SUPABASE_URL",
                "\"${localProperties.requireProperty("SUPABASE_URL")}\""
            )
            buildConfigField(
                "String",
                "GATEWAY_URL",
                "\"${localProperties.requireProperty("GATEWAY_URL")}\""
            )
            buildConfigField(
                "String",
                "STRIPE_PUBLISHABLE_KEY",
                "\"${localProperties.requireProperty("STRIPE_PUBLISHABLE_KEY")}\""
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons.extended)
    implementation(libs.androidx.navigation.compose)
    implementation(platform(libs.supabase.bom))
    implementation(libs.supabase.auth)
    implementation(libs.supabase.postgrest)
    implementation(libs.supabase.realtime)
    implementation(libs.supabase.storage)
    implementation(libs.supabase.functions)
    implementation(libs.ktor.client.okhttp)
    implementation(libs.credentials)
    implementation(libs.credentials.play.services.auth)
    implementation(libs.googleid)
    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.analytics)
    implementation(libs.stripe.android)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}
