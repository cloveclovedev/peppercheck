package dev.cloveclove.peppercheck.ui.components.common

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import dev.cloveclove.peppercheck.ui.theme.AccentBlueLight
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun BaseTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    minLines: Int = 1,
    maxLines: Int = Int.MAX_VALUE,
    readOnly: Boolean = false,
    enabled: Boolean = true,
    onClick: (() -> Unit)? = null,
    trailingIcon: (@Composable () -> Unit)? = null
) {
    val interactionSource = remember { MutableInteractionSource() }
    val content = @Composable {
        TextField(
            value = value,
            onValueChange = onValueChange,
            label = { 
                Text(label)
            },
            readOnly = readOnly,
            enabled = enabled,
            trailingIcon = trailingIcon,
            modifier = modifier.fillMaxWidth(),
            minLines = minLines,
            maxLines = maxLines,
            interactionSource = interactionSource,
            colors = TextFieldDefaults.colors(
                focusedIndicatorColor = AccentBlueLight,
                unfocusedIndicatorColor = AccentBlueLight.copy(alpha = 0.6f),
                focusedLabelColor = TextBlack.copy(alpha = 0.6f),
                unfocusedLabelColor = TextBlack.copy(alpha = 0.6f),
                focusedContainerColor = Color.Transparent,
                unfocusedContainerColor = Color.Transparent,
                disabledContainerColor = Color.Transparent,
                disabledIndicatorColor = AccentBlueLight.copy(alpha = 0.6f),
                disabledLabelColor = TextBlack.copy(alpha = 0.6f),
                disabledTextColor = TextBlack,
                focusedTextColor = TextBlack,
                unfocusedTextColor = TextBlack,
                cursorColor = AccentBlueLight
            )
        )
    }
    
    if (onClick != null) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(
                    interactionSource = interactionSource,
                    indication = null
                ) {
                    onClick()
                }
        ) {
            content()
        }
    } else {
        content()
    }
}

