package dev.cloveclove.peppercheck.data.stripe

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class StripeAccount(
    @SerialName("profile_id")
    val profileId: String,
    @SerialName("stripe_customer_id")
    val stripeCustomerId: String? = null,
    @SerialName("default_payment_method_id")
    val defaultPaymentMethodId: String? = null,
    @SerialName("pm_brand")
    val paymentMethodBrand: String? = null,
    @SerialName("pm_last4")
    val paymentMethodLast4: String? = null,
    @SerialName("pm_exp_month")
    val paymentMethodExpMonth: Int? = null,
    @SerialName("pm_exp_year")
    val paymentMethodExpYear: Int? = null,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("updated_at")
    val updatedAt: String? = null
)
