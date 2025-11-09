package dev.cloveclove.peppercheck.ui.components.profile

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.data.stripe.StripeAccount
import dev.cloveclove.peppercheck.ui.components.common.ActionButton
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun StripePaymentMethodSection(
    stripeAccount: StripeAccount?,
    isLoading: Boolean,
    onRegisterPaymentMethodClick: () -> Unit
) {
    val needsRegistration = stripeAccount?.stripeCustomerId.isNullOrBlank() ||
        stripeAccount?.defaultPaymentMethodId.isNullOrBlank()

    BaseSection(title = "Payment Method") {
        if (needsRegistration) {
            Text(
                text = "Add a payment method so we can register your payouts.",
                color = TextBlack.copy(alpha = 0.6f),
                style = MaterialTheme.typography.bodyMedium
            )
            Spacer(modifier = Modifier.height(16.dp))
            ActionButton(
                text = "Register payment method",
                icon = Icons.Filled.CreditCard,
                onClick = onRegisterPaymentMethodClick,
                fillMaxWidth = true,
                active = !isLoading
            )
        } else {
            val brandLabel = stripeAccount.paymentMethodBrand?.replaceFirstChar { it.uppercaseChar() } ?: "Card"
            val last4Label = stripeAccount.paymentMethodLast4?.padStart(4, '•') ?: "••••"
            val expMonth = stripeAccount.paymentMethodExpMonth
            val expYear = stripeAccount.paymentMethodExpYear
            val expirationLabel = if (expMonth != null && expYear != null) {
                "%02d/%02d".format(expMonth, expYear % 100)
            } else {
                "--/--"
            }

            Text(
                text = "Default payment method",
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                color = TextBlack
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "$brandLabel •••• $last4Label  exp $expirationLabel",
                style = MaterialTheme.typography.bodyLarge,
                color = TextBlack
            )
        }
    }
}
