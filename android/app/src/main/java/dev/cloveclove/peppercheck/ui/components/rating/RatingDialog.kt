package dev.cloveclove.peppercheck.ui.components.rating

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import dev.cloveclove.peppercheck.ui.theme.*

@Composable
fun RatingDialog(
    targetUserName: String,
    rating: Int,
    comment: String,
    isSubmitEnabled: Boolean,
    onRatingChanged: (Int) -> Unit,
    onCommentChanged: (String) -> Unit,
    onRatingSubmit: () -> Unit,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .wrapContentHeight(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = BackGroundWhite)
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "Confirm Judgement",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = TextBlack
                )

                Text(
                    text = "Please confirm this judgement by rating $targetUserName's performance.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextBlack.copy(alpha = 0.8f)
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    repeat(5) { index ->
                        val starNumber = index + 1
                        Icon(
                            imageVector = if (starNumber <= rating) Icons.Filled.Star else Icons.Outlined.Star,
                            contentDescription = "$starNumber star",
                            tint = if (starNumber <= rating) AccentYellow else TextBlack.copy(alpha = 0.3f),
                            modifier = Modifier
                                .size(32.dp)
                                .clickable { onRatingChanged(starNumber) }
                        )
                    }
                }

                OutlinedTextField(
                    value = comment,
                    onValueChange = onCommentChanged,
                    label = { Text("Comment (optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AccentYellow,
                        unfocusedBorderColor = BackGroundLight,
                        focusedLabelColor = AccentYellow,
                        focusedTextColor = TextBlack,
                        unfocusedTextColor = TextBlack,
                        cursorColor = AccentBlueLight
                    ),
                    minLines = 3
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    OutlinedButton(
                        onClick = onDismiss,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = TextBlack
                        )
                    ) {
                        Text("Cancel")
                    }

                    Button(
                        onClick = onRatingSubmit,
                        enabled = isSubmitEnabled,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = AccentYellow,
                            contentColor = Color.White,
                            disabledContainerColor = BackGroundLight
                        )
                    ) {
                        Text("Confirm")
                    }
                }
            }
        }
    }
}

