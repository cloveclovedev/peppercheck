package dev.cloveclove.peppercheck.ui.components.profile

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun PayoutAmountDialog(
    amountMinor: Long,
    currencyCode: String,
    isSubmitting: Boolean,
    onAmountChange: (Long) -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    val textState = remember(amountMinor) { mutableStateOf(amountMinor.toString()) }
    val isValid = textState.value.toLongOrNull()?.let { it > 0 } == true

    AlertDialog(
        onDismissRequest = { if (!isSubmitting) onDismiss() },
        title = {
            Text(
                text = "Enter payout amount",
                style = MaterialTheme.typography.titleMedium,
                color = TextBlack
            )
        },
        text = {
            Column(modifier = Modifier.fillMaxWidth()) {
                OutlinedTextField(
                    value = textState.value,
                    onValueChange = { text ->
                        textState.value = text.filter { it.isDigit() }
                        textState.value.toLongOrNull()?.let { onAmountChange(it) }
                    },
                    label = { Text("Amount ($currencyCode)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                )
                Text(
                    text = "Enter the amount you want to withdraw.",
                    style = MaterialTheme.typography.bodySmall,
                    color = TextBlack.copy(alpha = 0.7f),
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
        },
        confirmButton = {
            Button(
                onClick = onConfirm,
                enabled = isValid && !isSubmitting,
                colors = ButtonDefaults.buttonColors(containerColor = AccentYellow)
            ) {
                Text(text = if (isSubmitting) "Submitting…" else "Submit", color = TextBlack)
            }
        },
        dismissButton = {
            TextButton(onClick = { if (!isSubmitting) onDismiss() }) {
                Text(text = "Cancel")
            }
        }
    )
}
