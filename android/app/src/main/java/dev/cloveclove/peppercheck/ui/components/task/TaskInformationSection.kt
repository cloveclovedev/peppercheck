package dev.cloveclove.peppercheck.ui.components.task

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.components.common.ActionButton
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.data.task.Task
import dev.cloveclove.peppercheck.ui.common.formatUtcToLocal
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun TaskInformationSection(
    task: Task,
    isEditing: Boolean = false,
    onEditClick: (() -> Unit)? = null
) {
    val formattedDueDate = remember(task.dueDate) {
        task.dueDate?.let { dueDate ->
            formatUtcToLocal(dueDate, pattern = "yyyy/MM/dd HH:mm")
        } ?: ""
    }
    BaseSection(
        title = "Task Information"
    ) {
        // Display task title prominently within the content
        Text(
            text = task.title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = TextBlack
        )
        Spacer(modifier = Modifier.height(8.dp))
        
        if (task.description?.isNotBlank() == true) {
            Text(
                text = "Description",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium,
                color = TextBlack
            )
            Text(
                text = task.description,
                style = MaterialTheme.typography.bodyMedium,
                color = TextBlack
            )
            Spacer(modifier = Modifier.height(8.dp))
        }
        
        if (task.criteria?.isNotBlank() == true) {
            Text(
                text = "Criteria",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium,
                color = TextBlack
            )
            Text(
                text = task.criteria,
                style = MaterialTheme.typography.bodyMedium,
                color = TextBlack
            )
            Spacer(modifier = Modifier.height(8.dp))
        }
        
        // Due date and Fee in the same row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(32.dp),
            verticalAlignment = Alignment.Top
        ) {
            // Due date (left side)
            Column {
                Text(
                    text = "Due date",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium,
                    color = TextBlack
                )
                Text(
                    text = formattedDueDate,
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextBlack
                )
            }
            
            // Fee (left aligned with spacing)
            Column {
                Text(
                    text = "Fee",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium,
                    color = TextBlack
                )
                Text(
                    text = if (task.feeAmount != null) "¥${task.feeAmount.toInt()}" else "未設定",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextBlack
                )
            }
        }
        
        // Edit button for draft tasks (full width)
        if (task.status == "draft" && onEditClick != null && !isEditing) {
            Spacer(modifier = Modifier.height(12.dp))
            ActionButton(
                text = "Edit",
                icon = Icons.Default.Edit,
                onClick = onEditClick,
                fillMaxWidth = true
            )
        }
    }
}
