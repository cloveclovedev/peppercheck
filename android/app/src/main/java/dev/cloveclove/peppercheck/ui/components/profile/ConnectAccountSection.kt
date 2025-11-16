package dev.cloveclove.peppercheck.ui.components.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.data.stripe.StripeAccount
import dev.cloveclove.peppercheck.ui.components.common.ActionButton
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.screens.profile.ConnectLinkState
import dev.cloveclove.peppercheck.ui.theme.AccentGreenLight
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.TextBlack

private enum class PayoutSetupState {
    NOT_STARTED, ACTION_REQUIRED, COMPLETED
}

@Composable
fun ConnectAccountSection(
    stripeAccount: StripeAccount?,
    connectLinkState: ConnectLinkState,
    onSetupClick: () -> Unit
) {
    val state = when {
        stripeAccount?.stripeConnectAccountId.isNullOrBlank() -> PayoutSetupState.NOT_STARTED
        stripeAccount?.payoutsEnabled == true -> PayoutSetupState.COMPLETED
        else -> PayoutSetupState.ACTION_REQUIRED
    }

    BaseSection(title = "Payout Settings") {
        when (state) {
            PayoutSetupState.NOT_STARTED -> {
                Text(
                    text = "You have not started the payout onboarding yet.",
                    color = TextBlack.copy(alpha = 0.7f),
                    style = MaterialTheme.typography.bodyMedium
                )
                Spacer(modifier = Modifier.height(16.dp))
                ActionButton(
                    text = "Start payout setup",
                    icon = Icons.Default.AccountBalance,
                    onClick = onSetupClick,
                    fillMaxWidth = true,
                    active = connectLinkState !is ConnectLinkState.Loading
                )
                Spacer(modifier = Modifier.height(12.dp))
                PayoutGuidance()
            }
            PayoutSetupState.ACTION_REQUIRED -> {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "Action required to receive payouts.",
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium)
                    )
                    Text(
                        text = "Finish onboarding on Stripe to enable payouts.",
                        color = TextBlack.copy(alpha = 0.7f),
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
                Spacer(modifier = Modifier.height(16.dp))
                ActionButton(
                    text = "Resume Stripe onboarding",
                    icon = Icons.Default.AccountBalance,
                    onClick = onSetupClick,
                    fillMaxWidth = true,
                    active = connectLinkState !is ConnectLinkState.Loading
                )
                Spacer(modifier = Modifier.height(12.dp))
                PayoutGuidance()
            }
            PayoutSetupState.COMPLETED -> {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "Payout setup complete",
                        color = AccentGreenLight,
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium)
                    )
                    Text(
                        text = "Your Stripe Express account is ready to receive payouts.",
                        color = TextBlack.copy(alpha = 0.7f),
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }

        when (connectLinkState) {
            is ConnectLinkState.Loading -> {
                Spacer(modifier = Modifier.height(12.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = AccentYellow
                    )
                    Text(
                        text = "Generating onboarding link…",
                        color = TextBlack.copy(alpha = 0.7f),
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
            is ConnectLinkState.Error -> {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = "Error: ${connectLinkState.message}",
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall
                )
            }
            else -> {}
        }
    }
}

@Composable
private fun PayoutGuidance() {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = "To receive payouts, Stripe requires some information about the type of service you provide on Peppercheck.",
            color = TextBlack.copy(alpha = 0.7f),
            style = MaterialTheme.typography.bodySmall
        )
        Text(
            text = "Suggested inputs:",
            color = TextBlack.copy(alpha = 0.7f),
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium)
        )
        Text(
            text = "• Industry: \"Other personal services\"",
            color = TextBlack.copy(alpha = 0.7f),
            style = MaterialTheme.typography.bodySmall
        )
        Text(
            text = "• Website: https://peppercheck.com",
            color = TextBlack.copy(alpha = 0.7f),
            style = MaterialTheme.typography.bodySmall
        )
        Text(
            text = "• Description: \"I provide task review and checking services on the Peppercheck platform.\"",
            color = TextBlack.copy(alpha = 0.7f),
            style = MaterialTheme.typography.bodySmall
        )
    }
}
