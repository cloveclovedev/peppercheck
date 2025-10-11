package dev.cloveclove.peppercheck.ui.components.profile

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.screens.profile.ConnectLinkState
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun ConnectAccountSection(
    connectLinkState: ConnectLinkState,
    onSetupClick: () -> Unit
) {
    BaseSection(title = "Payment Settings") {
        Text("This is required to receive payouts", color = TextBlack.copy(alpha = 0.6f))
        Spacer(modifier = Modifier.height(16.dp))
        Button(
            onClick = onSetupClick,
            enabled = connectLinkState !is ConnectLinkState.Loading
        ) {
            Text("Setup Stripe Connect Account")
        }

        when (connectLinkState) {
            is ConnectLinkState.Loading -> {
                Spacer(modifier = Modifier.height(8.dp))
                CircularProgressIndicator(color = AccentYellow)
            }
            is ConnectLinkState.Error -> {
                Spacer(modifier = Modifier.height(8.dp))
                Text("Error: ${connectLinkState.message}", color = MaterialTheme.colorScheme.error)
            }
            else -> {}
        }
    }
}