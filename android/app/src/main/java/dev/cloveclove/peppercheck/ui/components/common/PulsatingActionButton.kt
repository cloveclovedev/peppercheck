package dev.cloveclove.peppercheck.ui.components.common

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun PulsatingActionButton(
    text: String,
    onClick: () -> Unit,
    enabled: Boolean,
    isLoading: Boolean = false,
    modifier: Modifier = Modifier
) {
    // 💓 脈打ちアニメーション（0.95f ↔ 1.0f）
    val infiniteTransition = rememberInfiniteTransition()
    val pulsateScale by infiniteTransition.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        )
    )
    val scale = if (enabled) pulsateScale else 0.95f

    Button(
        modifier = modifier
            .fillMaxWidth()
            .scale(scale),
        onClick = onClick,
        enabled = enabled && !isLoading,
        colors = ButtonDefaults.buttonColors(
            containerColor = AccentYellow,
            disabledContainerColor = Color.Gray.copy(alpha = 0.3f)
        )
    ) {
        Text(
            text = if (isLoading) "Saving..." else text,
            color = if (enabled) TextBlack else Color.Gray
        )
    }
}