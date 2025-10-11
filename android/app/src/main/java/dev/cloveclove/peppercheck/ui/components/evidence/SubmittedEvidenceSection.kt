package dev.cloveclove.peppercheck.ui.components.evidence

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.components.common.ActionButton
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.components.common.ImageExpandedDialog
import dev.cloveclove.peppercheck.ui.components.common.ImageItem
import dev.cloveclove.peppercheck.data.evidence.TaskEvidence
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun SubmittedEvidenceSection(
    evidence: TaskEvidence?,
    onEditEvidence: (() -> Unit)? = null
) {
    // State management for image expansion
    var expandedImageUrl by remember { mutableStateOf<String?>(null) }
    
    BaseSection(
        title = "Submitted Evidence"
    ) {
        if (evidence != null) {
            // Flat design: display directly without cards
            Text(
                text = evidence.description,
                style = MaterialTheme.typography.bodyMedium,
                color = TextBlack
            )
            
            // Display only assets with publicUrl
            val displayableAssets = evidence.taskEvidenceAssets.filter { it.publicUrl != null }
            if (displayableAssets.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                
                // Display images
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(displayableAssets) { asset ->
                        ImageItem(
                            imageUrl = asset.publicUrl,
                            contentDescription = "Evidence image",
                            onClick = { expandedImageUrl = asset.publicUrl }
                        )
                    }
                }
            }
            
            // Edit button at the bottom
            if (onEditEvidence != null) {
                Spacer(modifier = Modifier.height(8.dp))
                ActionButton(
                    text = "Edit",
                    icon = Icons.Default.Edit,
                    onClick = onEditEvidence,
                    fillMaxWidth = true
                )
            }
        } else {
            Text(
                text = "No evidence has been submitted yet",
                style = MaterialTheme.typography.bodyMedium,
                color = TextBlack.copy(alpha = 0.6f),
                modifier = Modifier.padding(vertical = 16.dp)
            )
        }
    }
    
    // Image expansion dialog
    ImageExpandedDialog(
        imageUrl = expandedImageUrl,
        onDismiss = { expandedImageUrl = null }
    )
}