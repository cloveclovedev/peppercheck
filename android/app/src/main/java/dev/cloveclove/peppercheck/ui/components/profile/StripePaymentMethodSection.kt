package dev.cloveclove.peppercheck.ui.components.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.data.stripe.StripeAccount
import dev.cloveclove.peppercheck.ui.components.common.ActionButton
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.theme.AccentBlueLight
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun StripePaymentMethodSection(
    stripeAccount: StripeAccount?,
    isSetupInProgress: Boolean,
    statusMessage: String?,
    errorMessage: String?,
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
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                ActionButton(
                    text = "Register payment method",
                    icon = Icons.Filled.CreditCard,
                    onClick = onRegisterPaymentMethodClick,
                    modifier = Modifier.weight(1f),
                    fillMaxWidth = true,
                    active = !isSetupInProgress
                )
                if (isSetupInProgress) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                }
            }
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

        if (!statusMessage.isNullOrBlank()) {
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = statusMessage,
                color = AccentBlueLight,
                style = MaterialTheme.typography.bodyMedium
            )
        }

        if (!errorMessage.isNullOrBlank()) {
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = errorMessage,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}
