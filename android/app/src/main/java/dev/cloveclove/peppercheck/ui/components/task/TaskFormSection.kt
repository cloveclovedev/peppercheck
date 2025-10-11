package dev.cloveclove.peppercheck.ui.components.task

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.components.common.BaseTextField
import dev.cloveclove.peppercheck.ui.theme.AccentBlueLight
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

@Composable
fun TaskFormSection(
    title: String,
    onTitleChange: (String) -> Unit,
    description: String,
    onDescriptionChange: (String) -> Unit,
    criteria: String,
    onCriteriaChange: (String) -> Unit,
    selectedDateTime: LocalDateTime?,
    onDateTimeClick: () -> Unit,
    taskStatus: String,
    onStatusChange: (String) -> Unit
) {
    val formatter = DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm")
    
    BaseSection(title = "Task Information") {
        BaseTextField(
            value = title,
            onValueChange = onTitleChange,
            label = "Title"
        )
        // Spacer(modifier = Modifier.height(4.dp))

        BaseTextField(
            value = description,
            onValueChange = onDescriptionChange,
            label = "Description (Optional)"
        )
        // Spacer(modifier = Modifier.height(4.dp))

        BaseTextField(
            value = criteria,
            onValueChange = onCriteriaChange,
            label = "Criteria"
        )
        // Spacer(modifier = Modifier.height(4.dp))

        BaseTextField(
            value = selectedDateTime?.format(formatter) ?: "",
            onValueChange = {},
            label = "Deadline",
            readOnly = true,
            enabled = false,
            onClick = onDateTimeClick,
            trailingIcon = {
                Icon(
                    Icons.Default.AccessTime,
                    contentDescription = "Select date and time",
                    tint = AccentBlueLight,
                    modifier = Modifier.padding(end = 4.dp)
                )
            }
        )
        Spacer(modifier = Modifier.height(8.dp))

        // Task Status Selector inside Task Details section
        TaskStatusSelector(
            selectedStatus = taskStatus,
            onStatusChange = onStatusChange
        )
    }
}

