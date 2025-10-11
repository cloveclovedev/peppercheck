package dev.cloveclove.peppercheck.ui.components.task

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.data.task.Task
import dev.cloveclove.peppercheck.ui.theme.AccentBlueLight
import dev.cloveclove.peppercheck.ui.theme.AccentGreen
import dev.cloveclove.peppercheck.ui.theme.AccentGreenLight
import dev.cloveclove.peppercheck.ui.theme.AccentRed
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.BackGroundWhite
import dev.cloveclove.peppercheck.ui.theme.TextBlack
import dev.cloveclove.peppercheck.ui.common.formatUtcToLocal

@Composable
fun TaskCard(task: Task, onTaskClick: (Task) -> Unit) {
    val dueDateFormatted = formatUtcToLocal(task.dueDate, pattern = "MM/dd HH:mm")

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 1.dp)
            .clickable { onTaskClick(task) },
        colors = CardDefaults.cardColors(
            containerColor = BackGroundWhite
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.Person, 
                    contentDescription = null, 
                    tint = TextBlack,
                    modifier = Modifier.width(16.dp).height(16.dp)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Column {
                    Text(
                        text = task.title,
                        color = TextBlack,
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        text = "Due: $dueDateFormatted • ¥${task.feeAmount?.toInt() ?: 0}",
                        color = TextBlack.copy(alpha = 0.7f),
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
            Text(
                text = task.status,
                color = when (task.status) {
                    "draft" -> TextBlack.copy(alpha = 0.6f)
                    "open" -> AccentYellow
                    "judging" -> AccentBlueLight
                    "rejected" -> AccentRed
                    "completed" -> AccentGreenLight
                    "closed" -> AccentGreen.copy(alpha = 0.7f)
                    "self_completed" -> AccentGreen.copy(alpha = 0.5f)
                    "expired" -> TextBlack.copy(alpha = 0.4f)
                    "done" -> AccentGreenLight
                    else -> TextBlack
                },
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}
