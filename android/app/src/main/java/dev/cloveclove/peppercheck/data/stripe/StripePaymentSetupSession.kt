package dev.cloveclove.peppercheck.data.stripe

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class StripePaymentSetupSession(
    @SerialName("customerId")
    val customerId: String,
    @SerialName("setupIntentClientSecret")
    val setupIntentClientSecret: String,
    @SerialName("ephemeralKeySecret")
    val ephemeralKeySecret: String
)
