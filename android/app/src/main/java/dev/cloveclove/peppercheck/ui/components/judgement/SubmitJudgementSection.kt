package dev.cloveclove.peppercheck.ui.components.judgement

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.components.common.BaseTextField
import dev.cloveclove.peppercheck.ui.components.common.PrimaryActionButton
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.BackGroundLight
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun SubmitJudgementSection(
    comment: String,
    onCommentChange: (String) -> Unit,
    selectedStatus: String?,
    onStatusSelected: (String) -> Unit,
    isSubmitEnabled: Boolean,
    onSubmitClick: () -> Unit
) {
    BaseSection(title = "Submit Judgement") {
        BaseTextField(value = comment, onValueChange = onCommentChange, label = "Comment")
        Spacer(modifier = Modifier.height(8.dp))
        
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = { onStatusSelected("approved") },
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (selectedStatus == "approved") AccentYellow else BackGroundLight,
                    contentColor = TextBlack
                ),
                shape = RoundedCornerShape(12.dp)
            ) { Text("Approve", fontWeight = FontWeight.Medium) }
            
            Button(
                onClick = { onStatusSelected("rejected") },
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (selectedStatus == "rejected") MaterialTheme.colorScheme.errorContainer else BackGroundLight,
                    contentColor = if (selectedStatus == "rejected") MaterialTheme.colorScheme.onErrorContainer else TextBlack
                ),
                shape = RoundedCornerShape(12.dp)
            ) { Text("Reject", fontWeight = FontWeight.Medium) }
        }
        
        Spacer(modifier = Modifier.height(8.dp))
        PrimaryActionButton(
            text = if (selectedStatus != null) "Submit ${selectedStatus.replaceFirstChar { it.uppercaseChar() }}" else "Submit Judgement",
            enabled = isSubmitEnabled,
            onClick = onSubmitClick,
            modifier = Modifier.fillMaxWidth()
        )
    }
}
