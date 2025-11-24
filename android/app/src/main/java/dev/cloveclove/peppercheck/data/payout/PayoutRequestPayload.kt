package dev.cloveclove.peppercheck.data.payout

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class PayoutRequestPayload(
    @SerialName("amount_minor")
    val amountMinor: Long,
    @SerialName("currency_code")
    val currencyCode: String = "JPY"
)
