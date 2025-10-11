package dev.cloveclove.peppercheck.ui.components.profile

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TimePickerDefaults
import androidx.compose.material3.TimePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.BackGroundLight
import dev.cloveclove.peppercheck.ui.theme.TextBlack

data class DayOfWeek(val index: Int, val name: String, val shortName: String)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddAvailableTimeSlotDialog(
    selectedDay: Int,
    startTime: java.time.LocalTime,
    endTime: java.time.LocalTime,
    onDismiss: () -> Unit,
    onDaySelected: (Int) -> Unit,
    onStartTimeSelected: (java.time.LocalTime) -> Unit,
    onEndTimeSelected: (java.time.LocalTime) -> Unit,
    onConfirm: () -> Unit
) {
    var step by remember { mutableStateOf(AvailabilityDialogStep.DAY_SELECTION) }
    var selectedDayIndex by remember { mutableStateOf(selectedDay) }
    
    val startTimeState = rememberTimePickerState(initialHour = startTime.hour, initialMinute = startTime.minute, is24Hour = true)
    val endTimeState = rememberTimePickerState(initialHour = endTime.hour, initialMinute = endTime.minute, is24Hour = true)
    
    val daysOfWeek = listOf(
        DayOfWeek(0, "Sunday", "Sun"),
        DayOfWeek(1, "Monday", "Mon"),
        DayOfWeek(2, "Tuesday", "Tue"),
        DayOfWeek(3, "Wednesday", "Wed"),
        DayOfWeek(4, "Thursday", "Thu"),
        DayOfWeek(5, "Friday", "Fri"),
        DayOfWeek(6, "Saturday", "Sat")
    )
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = when (step) {
                    AvailabilityDialogStep.DAY_SELECTION -> "Select Day"
                    AvailabilityDialogStep.START_TIME -> "Select Start Time"
                    AvailabilityDialogStep.END_TIME -> "Select End Time"
                },
                style = MaterialTheme.typography.titleMedium,
                color = TextBlack
            )
        },
        text = {
            when (step) {
                AvailabilityDialogStep.DAY_SELECTION -> {
                    DaySelectionContent(
                        daysOfWeek = daysOfWeek,
                        selectedDayIndex = selectedDayIndex,
                        onDaySelected = { selectedDayIndex = it }
                    )
                }
                AvailabilityDialogStep.START_TIME -> {
                    TimeSelectionContent(
                        timePickerState = startTimeState,
                        label = "Start Time"
                    )
                }
                AvailabilityDialogStep.END_TIME -> {
                    TimeSelectionContent(
                        timePickerState = endTimeState,
                        label = "End Time"
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    when (step) {
                        AvailabilityDialogStep.DAY_SELECTION -> {
                            onDaySelected(selectedDayIndex)
                            step = AvailabilityDialogStep.START_TIME
                        }
                        AvailabilityDialogStep.START_TIME -> {
                            onStartTimeSelected(java.time.LocalTime.of(startTimeState.hour, startTimeState.minute))
                            step = AvailabilityDialogStep.END_TIME
                        }
                        AvailabilityDialogStep.END_TIME -> {
                            onEndTimeSelected(java.time.LocalTime.of(endTimeState.hour, endTimeState.minute))
                            onConfirm()
                        }
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = AccentYellow)
            ) {
                Text(
                    text = when (step) {
                        AvailabilityDialogStep.DAY_SELECTION -> "Next"
                        AvailabilityDialogStep.START_TIME -> "Next"
                        AvailabilityDialogStep.END_TIME -> "Add"
                    },
                    color = TextBlack
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = TextBlack)
            }
        },
        containerColor = BackGroundLight,
        tonalElevation = 0.dp
    )
}

@Composable
private fun DaySelectionContent(
    daysOfWeek: List<DayOfWeek>,
    selectedDayIndex: Int,
    onDaySelected: (Int) -> Unit
) {
    LazyColumn(
        modifier = Modifier.height(300.dp)
    ) {
        itemsIndexed(daysOfWeek) { _, day ->
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 2.dp)
                    .selectable(
                        selected = selectedDayIndex == day.index,
                        onClick = { onDaySelected(day.index) },
                        role = Role.RadioButton
                    ),
                colors = CardDefaults.cardColors(
                    containerColor = if (selectedDayIndex == day.index) AccentYellow else Color.White
                ),
                shape = RoundedCornerShape(8.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    RadioButton(
                        selected = selectedDayIndex == day.index,
                        onClick = { onDaySelected(day.index) },
                        colors = RadioButtonDefaults.colors(
                            selectedColor = TextBlack,
                            unselectedColor = TextBlack.copy(alpha = 0.6f)
                        )
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = day.name,
                        style = MaterialTheme.typography.bodyMedium,
                        color = TextBlack
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TimeSelectionContent(
    timePickerState: TimePickerState,
    label: String
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = TextBlack,
            modifier = Modifier.padding(bottom = 16.dp)
        )
        TimePicker(
            state = timePickerState,
            colors = TimePickerDefaults.colors(
                containerColor = Color.White,
                timeSelectorSelectedContainerColor = AccentYellow,
                timeSelectorUnselectedContainerColor = Color.White,
                timeSelectorSelectedContentColor = TextBlack,
                timeSelectorUnselectedContentColor = TextBlack
            )
        )
    }
}


private enum class AvailabilityDialogStep {
    DAY_SELECTION,
    START_TIME,
    END_TIME
}