package dev.cloveclove.peppercheck.ui.components.task

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.components.common.ActionButton
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun MatchingStrategySelectionSection(
    selectedStrategies: List<String>,
    onStrategiesChange: (List<String>) -> Unit
) {
    val totalFee = selectedStrategies.size * 50 // Standard = ¥50 each

    BaseSection(title = "Matching request & Commitment fee") {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            selectedStrategies.forEach { strategy ->
                StrategyButton(
                    strategy = strategy,
                    onRemove = { 
                        onStrategiesChange(selectedStrategies - strategy)
                    }
                )
            }
            
            // Add button (+ button)
            if (selectedStrategies.size < 2) {
                ActionButton(
                    text = "Add",
                    icon = Icons.Default.Add,
                    onClick = { 
                        onStrategiesChange(selectedStrategies + "standard")
                    }
                )
            }
        }
        
        if (selectedStrategies.isNotEmpty()) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "¥$totalFee",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = TextBlack,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.End
            )
        }
    }
}