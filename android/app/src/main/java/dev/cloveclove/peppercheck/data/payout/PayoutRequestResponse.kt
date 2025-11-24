package dev.cloveclove.peppercheck.data.payout

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class PayoutRequestResponse(
    val id: String,
    val status: String,
    @SerialName("provider_payout_id")
    val providerPayoutId: String? = null
)
