package dev.cloveclove.peppercheck.ui.screens.create_task

import java.time.LocalDateTime

sealed class CreateTaskEvent {
    data class TitleChanged(val value: String) : CreateTaskEvent()
    data class DescriptionChanged(val value: String) : CreateTaskEvent()
    data class CriteriaChanged(val value: String) : CreateTaskEvent()
    data class StatusChanged(val value: String) : CreateTaskEvent()
    data class StrategiesChanged(val value: List<String>) : CreateTaskEvent()
    data object DateTimeClicked : CreateTaskEvent()
    data object DatePickerDismissed : CreateTaskEvent()
    data object DateSelected : CreateTaskEvent()
    data class TimeSelected(val dateTime: LocalDateTime) : CreateTaskEvent()
    data object TimePickerDismissed : CreateTaskEvent()
    data object CreateTaskClicked : CreateTaskEvent()
    data object SuccessMessageConsumed : CreateTaskEvent() // 成功メッセージ表示後の状態リセット用
}