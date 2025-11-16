package dev.cloveclove.peppercheck.data.stripe

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class StripeAccount(
    @SerialName("profile_id")
    val profileId: String,
    @SerialName("stripe_customer_id")
    val stripeCustomerId: String? = null,
    @SerialName("stripe_connect_account_id")
    val stripeConnectAccountId: String? = null,
    @SerialName("charges_enabled")
    val chargesEnabled: Boolean? = null,
    @SerialName("payouts_enabled")
    val payoutsEnabled: Boolean? = null,
    @SerialName("connect_requirements")
    val connectRequirements: StripeConnectRequirements? = null,
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

@Serializable
data class StripeConnectRequirements(
    @SerialName("currently_due")
    val currentlyDue: List<String> = emptyList(),
    @SerialName("eventually_due")
    val eventuallyDue: List<String> = emptyList(),
    @SerialName("past_due")
    val pastDue: List<String> = emptyList(),
    @SerialName("pending_verification")
    val pendingVerification: List<String> = emptyList(),
    @SerialName("errors")
    val errors: List<StripeRequirementError> = emptyList()
)

@Serializable
data class StripeRequirementError(
    @SerialName("code")
    val code: String? = null,
    @SerialName("reason")
    val reason: String? = null,
    @SerialName("requirement")
    val requirement: String? = null
)
