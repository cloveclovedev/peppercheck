package dev.cloveclove.peppercheck.ui.components.common

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.theme.AccentBlueLight
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun ActionButton(
    text: String,
    icon: ImageVector,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    fillMaxWidth: Boolean = false,
    active: Boolean = true
) {
    val containerColor = AccentBlueLight.copy(alpha = 0.1f)
    val contentColor = AccentBlueLight
    val disabledContainerColor = TextBlack.copy(alpha = 0.05f)
    val disabledContentColor = TextBlack.copy(alpha = 0.4f)
    val borderColor = AccentBlueLight.copy(alpha = 0.5f)
    val disabledBorderColor = TextBlack.copy(alpha = 0.2f)
    
    Button(
        onClick = onClick,
        enabled = active,
        modifier = if (fillMaxWidth) modifier.fillMaxWidth() else modifier,
        colors = ButtonDefaults.buttonColors(
            containerColor = containerColor,
            contentColor = contentColor,
            disabledContainerColor = disabledContainerColor,
            disabledContentColor = disabledContentColor
        ),
        border = BorderStroke(
            2.dp,
            if (active) borderColor else disabledBorderColor
        ),
        shape = RoundedCornerShape(8.dp),
        contentPadding = if (fillMaxWidth) 
            PaddingValues(horizontal = 16.dp, vertical = 12.dp)
        else 
            PaddingValues(horizontal = 12.dp, vertical = 8.dp)
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(if (fillMaxWidth) 6.dp else 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                icon,
                contentDescription = text,
                tint = if (active) contentColor else disabledContentColor,
                modifier = Modifier.size(16.dp)
            )
            Text(
                text = text,
                style = MaterialTheme.typography.bodyLarge,
                color = if (active) contentColor else disabledContentColor,
                fontWeight = FontWeight.Medium
            )
        }
    }
}