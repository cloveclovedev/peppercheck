@file:OptIn(ExperimentalMaterial3Api::class)

package dev.cloveclove.peppercheck.ui.components.common

import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TimePickerDialog
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

@Composable
fun DateTimePickerDialogs(
    showDatePicker: Boolean,
    showTimePicker: Boolean,
    onDatePickerDismiss: () -> Unit,
    onTimePickerDismiss: () -> Unit,
    onDateSelected: () -> Unit, // Called when date is selected and should show time picker
    onDateTimeSelected: (LocalDateTime) -> Unit
) {
    val datePickerState = rememberDatePickerState()
    val timePickerState = rememberTimePickerState(is24Hour = true)

    if (showDatePicker) {
        DatePickerDialog(
            onDismissRequest = onDatePickerDismiss,
            confirmButton = {
                TextButton(onClick = {
                    if (datePickerState.selectedDateMillis != null) {
                        onDateSelected()
                    }
                }) {
                    Text("Next")
                }
            },
            dismissButton = {
                TextButton(onClick = onDatePickerDismiss) {
                    Text("Cancel")
                }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }

    if (showTimePicker) {
        TimePickerDialog(
            onDismissRequest = onTimePickerDismiss,
            confirmButton = {
                TextButton(onClick = {
                    val dateMillis = datePickerState.selectedDateMillis
                    if (dateMillis != null) {
                        val date = Instant.ofEpochMilli(dateMillis)
                            .atZone(ZoneId.systemDefault())
                            .toLocalDate()
                        val selected = date.atTime(timePickerState.hour, timePickerState.minute)
                        onDateTimeSelected(selected)
                    }
                    onTimePickerDismiss()
                }) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = onTimePickerDismiss) {
                    Text("Cancel")
                }
            },
            title = { Text("Select Time") }
        ) {
            TimePicker(state = timePickerState)
        }
    }
}