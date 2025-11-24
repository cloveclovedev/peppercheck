package dev.cloveclove.peppercheck.data.payout

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class PayoutJob(
    val id: String,
    @SerialName("user_id")
    val userId: String,
    val status: String,
    @SerialName("currency_code")
    val currencyCode: String,
    @SerialName("amount_minor")
    val amountMinor: Long,
    @SerialName("payment_provider")
    val paymentProvider: String,
    @SerialName("provider_payout_id")
    val providerPayoutId: String? = null,
    @SerialName("attempt_count")
    val attemptCount: Int,
    @SerialName("last_error_code")
    val lastErrorCode: String? = null,
    @SerialName("last_error_message")
    val lastErrorMessage: String? = null,
    @SerialName("created_at")
    val createdAt: String,
    @SerialName("updated_at")
    val updatedAt: String
)
