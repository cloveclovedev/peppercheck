package dev.cloveclove.peppercheck.ui.components.profile

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.data.referee_available_time_slot.RefereeAvailableTimeSlot
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun RefereeAvailableTimeSlotSection(
    timeSlots: List<RefereeAvailableTimeSlot>,
    isLoading: Boolean,
    error: String?,
    onAddClick: () -> Unit,
    onDeleteClick: (String) -> Unit
) {
    BaseSection(
        title = "Referee Availability",
        actions = { IconButton(onClick = onAddClick) { Icon(Icons.Default.Add, "Add") } }
    ) {
        when {
            isLoading -> {
                Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = AccentYellow)
                }
            }
            error != null -> Text("Error: $error", color = MaterialTheme.colorScheme.error)
            timeSlots.isEmpty() -> Text("No availability set.", color = TextBlack.copy(alpha = 0.6f))
            else -> {
                Column {
                    timeSlots.forEach { timeSlot ->
                        AvailableTimeSlotCard(
                            timeSlot = timeSlot,
                            onDelete = { onDeleteClick(timeSlot.id) }
                        )
                    }
                }
            }
        }
    }
}