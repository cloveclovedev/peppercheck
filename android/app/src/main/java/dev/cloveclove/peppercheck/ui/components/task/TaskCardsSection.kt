package dev.cloveclove.peppercheck.ui.components.task

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.data.task.Task
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun TaskCardsSection(
    title: String,
    tasks: List<Task>,
    onTaskClick: (Task) -> Unit,
    modifier: Modifier = Modifier
) {
    BaseSection(title = title, modifier = modifier) {
        if (tasks.isEmpty()) {
            Text(
                text = "No tasks yet",
                style = MaterialTheme.typography.bodyMedium,
                color = TextBlack.copy(alpha = 0.6f),
                modifier = Modifier.padding(16.dp)
            )
        } else {
            // Using forEach inside LazyColumn can cause performance issues,
            // so it's natural for this component to have the responsibility of displaying lists.
            // It's designed to be called within the item scope of LazyColumn from the caller.
            tasks.forEach { task ->
                TaskCard(task, onTaskClick)
            }
        }
    }
}