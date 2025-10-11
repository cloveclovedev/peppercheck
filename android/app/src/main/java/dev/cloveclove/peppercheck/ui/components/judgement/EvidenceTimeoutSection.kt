package dev.cloveclove.peppercheck.ui.components.judgement

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.components.common.*
import dev.cloveclove.peppercheck.ui.theme.*

@Composable
fun EvidenceTimeoutSection(
    onConfirmClick: () -> Unit,
    isConfirmEnabled: Boolean = true
) {
    BaseSection(title = "Submit Judgement") {
        Text(
            text = "Evidence was not submitted by the due date.",
            style = MaterialTheme.typography.bodyMedium,
            color = TextBlack.copy(alpha = 0.8f),
            fontWeight = FontWeight.Medium
        )
        
        Spacer(modifier = Modifier.height(12.dp))
        
        ActionButton(
            text = "Confirm",
            icon = Icons.Default.CheckCircle,
            onClick = onConfirmClick,
            fillMaxWidth = true,
            active = isConfirmEnabled
        )
        
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "Confirm to proceed with commitment fee payment.",
            style = MaterialTheme.typography.bodySmall,
            color = TextBlack.copy(alpha = 0.6f),
            modifier = Modifier.fillMaxWidth(),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }
}