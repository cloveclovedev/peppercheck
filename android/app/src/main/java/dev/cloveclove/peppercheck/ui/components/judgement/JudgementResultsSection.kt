package dev.cloveclove.peppercheck.ui.components.judgement

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import dev.cloveclove.peppercheck.ui.components.common.ActionButton
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.screens.task.shared.JudgementUiModel
import dev.cloveclove.peppercheck.ui.screens.task.shared.canBeConfirmed
import dev.cloveclove.peppercheck.ui.theme.*

@Composable
fun JudgementResultsSection(
    judgements: List<JudgementUiModel>,
    onConfirmJudgementClick: (JudgementUiModel) -> Unit = {},
    onReopenJudgementClick: (JudgementUiModel) -> Unit = {},
    showEvaluationMessage: Boolean = false,
    taskDueDate: String? = null
) {
    BaseSection(title = "Judgement Results") {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (showEvaluationMessage) {
                Text(
                    text = "Please confirm each judgement to close the task.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextBlack.copy(alpha = 0.8f),
                    modifier = Modifier.padding(bottom = 8.dp)
                )
            }
            
            Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                judgements.forEach { judgement ->
                    JudgementResultCard(
                        judgement = judgement,
                        onConfirmClick = if (judgement.canBeConfirmed) {
                            { onConfirmJudgementClick(judgement) }
                        } else {
                            null
                        },
                        onReopenClick = if (judgement.canReopen) {
                            { onReopenJudgementClick(judgement) }
                        } else {
                            null
                        },
                        taskDueDate = taskDueDate
                    )
                }
            }
        }
    }
}

@Composable
private fun JudgementResultCard(
    judgement: JudgementUiModel,
    onConfirmClick: (() -> Unit)? = null,
    onReopenClick: (() -> Unit)? = null,
    taskDueDate: String? = null
) {
    val statusText = when (judgement.status) {
        "open" -> "Awaiting Judgement"
        "approved" -> "Approved"
        "rejected" -> "Rejected"
        "judgement_timeout" -> "Judgement Timeout"
        "evidence_timeout" -> "Evidence Timeout"
        else -> judgement.status.replaceFirstChar { it.uppercaseChar() }
    }

    val statusColor = when (judgement.status) {
        "open" -> TextBlack.copy(alpha = 0.6f)
        "approved" -> AccentGreenLight
        "rejected" -> AccentRed
        "judgement_timeout", "evidence_timeout" -> TextBlack.copy(alpha = 0.4f)
        else -> TextBlack
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = BackGroundWhite)
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (judgement.refereeAvatarUrl != null) {
                    AsyncImage(
                        model = judgement.refereeAvatarUrl,
                        contentDescription = "Referee Avatar",
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(TextBlack.copy(alpha = 0.1f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Person,
                            contentDescription = "Default Profile Icon",
                            tint = TextBlack.copy(alpha = 0.6f),
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.width(12.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = statusText,
                        color = statusColor,
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Bold
                    )
                    if (!judgement.comment.isNullOrBlank()) {
                        Text(
                            text = judgement.comment,
                            color = TextBlack.copy(alpha = 0.8f),
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }

                if (judgement.isConfirmed) {
                    Icon(
                        Icons.Default.Check, 
                        contentDescription = "Confirmed",
                        tint = AccentGreenLight,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
            
            // ボタンセクション
            Column {
                // Confirmボタン
                if (onConfirmClick != null) {
                    Spacer(modifier = Modifier.height(12.dp))
                    ActionButton(
                        text = "Confirm",
                        icon = Icons.Default.CheckCircle,
                        onClick = onConfirmClick,
                        fillMaxWidth = true
                    )
                    
                    // タイムアウト時の説明文
                    if (judgement.status == "judgement_timeout") {
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = "Commitment fee payment will be cancelled.\nThe referee will automatically receive a score of 0.",
                            style = MaterialTheme.typography.bodySmall,
                            color = TextBlack.copy(alpha = 0.6f),
                            modifier = Modifier.fillMaxWidth(),
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                    }
                }
                
                // Reopenボタン - rejected判定かつ未confirmed の場合のみ表示
                if (judgement.status == "rejected" && !judgement.isConfirmed) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Column {
                        ActionButton(
                            text = "Request Re-judgement",
                            icon = Icons.Default.Refresh,
                            onClick = onReopenClick ?: { },
                            fillMaxWidth = true,
                            active = judgement.canReopen
                        )
                        if (!judgement.canReopen) {
                            Spacer(modifier = Modifier.height(2.dp))

                            val reopenBlockReasons = mutableListOf<String>()

                            if (judgement.reopenCount >= 1) {
                                reopenBlockReasons.add("Reopen is limited to once per task")
                            }

                            taskDueDate?.let { dueDate ->
                                try {
                                    val dueDateInstant = java.time.Instant.parse(dueDate)
                                    val now = java.time.Instant.now()
                                    if (!dueDateInstant.isAfter(now)) {
                                        reopenBlockReasons.add("Task deadline has passed")
                                    }
                                } catch (e: Exception) {
                                    // Skip
                                }
                            }

                            if (reopenBlockReasons.isEmpty()) {
                                reopenBlockReasons.add("Update evidence to request re-judgement")
                            }

                            reopenBlockReasons.forEach { reason ->
                                Text(
                                    text = reason,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = TextBlack.copy(alpha = 0.5f),
                                    modifier = Modifier.fillMaxWidth(),
                                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}