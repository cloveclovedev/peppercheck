package dev.cloveclove.peppercheck.ui.components.common

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import dev.cloveclove.peppercheck.ui.theme.BackGroundLight
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun CancelButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    text: String = "Cancel",
    enabled: Boolean = true
) {
    val containerColor = BackGroundLight.copy(alpha = 0.6f)
    val contentColor = TextBlack

    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.fillMaxWidth(),
        colors = ButtonDefaults.buttonColors(
            containerColor = containerColor,
            contentColor = contentColor,
            disabledContainerColor = containerColor.copy(alpha = 0.5f),
            disabledContentColor = contentColor.copy(alpha = 0.5f)
        )
    ) {
        Text(text = text)
    }
}
