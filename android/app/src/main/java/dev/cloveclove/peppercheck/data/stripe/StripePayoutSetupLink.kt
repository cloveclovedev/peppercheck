package dev.cloveclove.peppercheck.data.stripe

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class StripePayoutSetupLink(
    @SerialName("url")
    val url: String
)
