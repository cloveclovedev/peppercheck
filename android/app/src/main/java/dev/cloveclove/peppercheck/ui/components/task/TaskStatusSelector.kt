package dev.cloveclove.peppercheck.ui.components.task

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.BackGroundLight
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun TaskStatusSelector(
    selectedStatus: String,
    onStatusChange: (String) -> Unit
) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Button(
            onClick = { onStatusChange("draft") },
            colors = ButtonDefaults.buttonColors(
                containerColor = if (selectedStatus == "draft") AccentYellow else BackGroundLight
            ),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.weight(1f)
        ) {
            Text("Draft", color = TextBlack, fontWeight = FontWeight.Medium)
        }
        Button(
            onClick = { onStatusChange("open") },
            colors = ButtonDefaults.buttonColors(
                containerColor = if (selectedStatus == "open") AccentYellow else BackGroundLight
            ),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.weight(1f)
        ) {
            Text("Open", color = TextBlack, fontWeight = FontWeight.Medium)
        }
    }
}