package dev.cloveclove.peppercheck.ui.components.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.components.common.ActionButton
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.theme.TextBlack
import java.text.NumberFormat
import java.util.Locale

@Composable
fun PayoutRequestSection(
    availableMinor: Long?,
    pendingMinor: Long,
    incomingPendingMinor: Long,
    currencyCode: String,
    payoutsEnabled: Boolean,
    isInProgress: Boolean,
    message: String?,
    error: String?,
    onRequestClick: () -> Unit
) {
    val formatter = NumberFormat.getCurrencyInstance(Locale.JAPAN)
    formatter.currency = java.util.Currency.getInstance(currencyCode)
    val availableText = availableMinor?.let { formatter.format(it) } ?: "—"
    val pendingText = formatter.format(pendingMinor)
    val incomingPendingText = formatter.format(incomingPendingMinor)

    BaseSection(title = "Payouts") {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = "Withdrawable balance",
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                color = TextBlack
            )
            Text(
                text = availableText,
                style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                color = TextBlack
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = "Pending: $pendingText",
                style = MaterialTheme.typography.bodySmall,
                color = TextBlack.copy(alpha = 0.7f)
            )
            Text(
                text = "Incoming (not yet available): $incomingPendingText",
                style = MaterialTheme.typography.bodySmall,
                color = TextBlack.copy(alpha = 0.7f)
            )
            }
            Spacer(modifier = Modifier.height(8.dp))
            ActionButton(
                text = "Start payout",
                icon = Icons.Default.AccountBalanceWallet,
                onClick = onRequestClick,
                fillMaxWidth = true,
                active = payoutsEnabled && (availableMinor ?: 0L) > 0 && !isInProgress
            )
            if (message != null) {
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodySmall,
                    color = TextBlack.copy(alpha = 0.7f)
                )
            }
            if (error != null) {
                Text(
                    text = error,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error
                )
            }
        }
    }
}
