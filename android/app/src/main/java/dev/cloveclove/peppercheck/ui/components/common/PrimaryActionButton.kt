package dev.cloveclove.peppercheck.ui.components.common

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.TextBlack

/**
 * Primary call-to-action button used for the most important actions (e.g. create/save/submit).
 * Styling is aligned with the former PulsatingActionButton but without any animation.
 */
@Composable
fun PrimaryActionButton(
    text: String,
    onClick: () -> Unit,
    enabled: Boolean,
    isLoading: Boolean = false,
    modifier: Modifier = Modifier
) {
    Button(
        onClick = onClick,
        enabled = enabled && !isLoading,
        modifier = modifier.fillMaxWidth(),
        colors = ButtonDefaults.buttonColors(
            containerColor = AccentYellow,
            contentColor = TextBlack,
            disabledContainerColor = Color.Gray.copy(alpha = 0.3f),
            disabledContentColor = Color.Gray
        )
    ) {
        Text(text = if (isLoading) "Saving..." else text)
    }
}

