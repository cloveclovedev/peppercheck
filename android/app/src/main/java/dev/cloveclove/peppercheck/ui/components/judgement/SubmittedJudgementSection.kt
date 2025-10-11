package dev.cloveclove.peppercheck.ui.components.judgement

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.components.common.ActionButton
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.screens.task.shared.JudgementUiModel
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.AccentGreenLight
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun SubmittedJudgementSection(
    judgement: JudgementUiModel,
    onEditClick: (() -> Unit)? = null
) {
    BaseSection(title = "Submitted Judgement") {
        // Flat design like TaskInformation section
        Text(
            text = judgement.status.replaceFirstChar { it.uppercaseChar() },
            style = MaterialTheme.typography.titleMedium,
            color = when (judgement.status) {
                "approved" -> AccentYellow
                "rejected" -> MaterialTheme.colorScheme.error
                "Evidence Timeout Confirmed" -> AccentGreenLight
                else -> TextBlack
            },
            fontWeight = FontWeight.Bold
        )
        
        if (!judgement.comment.isNullOrBlank()) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Comment",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium,
                color = TextBlack
            )
            Text(
                text = judgement.comment,
                style = MaterialTheme.typography.bodyMedium,
                color = TextBlack
            )
        }
        
        Spacer(modifier = Modifier.height(12.dp))
        
        // Edit button (only show if onEditClick is provided)
        onEditClick?.let { editClick ->
            ActionButton(
                text = "Edit",
                icon = Icons.Default.Edit,
                onClick = editClick,
                fillMaxWidth = true
            )
        }
    }
}