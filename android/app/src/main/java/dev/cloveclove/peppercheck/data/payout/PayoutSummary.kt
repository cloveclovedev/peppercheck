package dev.cloveclove.peppercheck.data.payout

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class PayoutSummary(
    @SerialName("available_minor")
    val availableMinor: Long,
    @SerialName("pending_minor")
    val pendingMinor: Long,
    @SerialName("incoming_pending_minor")
    val incomingPendingMinor: Long,
    @SerialName("currency_code")
    val currencyCode: String
)
