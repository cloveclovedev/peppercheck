package dev.cloveclove.peppercheck.ui.screens.create_task

import java.time.LocalDateTime

data class CreateTaskUiState(
    // フォームの入力状態
    val title: String = "",
    val description: String = "",
    val criteria: String = "",
    val selectedDateTime: LocalDateTime? = null,
    val taskStatus: String = "draft",
    val selectedStrategies: List<String> = emptyList(),

    // ダイアログの表示状態
    val isDatePickerVisible: Boolean = false,
    val isTimePickerVisible: Boolean = false,

    // 非同期処理の状態
    val isLoading: Boolean = false,
    val isSuccess: Boolean = false,
    val error: String? = null
) {
    // フォームのバリデーションロジック
    val isFormValid: Boolean
        get() = when (taskStatus) {
            "draft" -> title.isNotBlank()
            "open" -> title.isNotBlank() && criteria.isNotBlank() && selectedDateTime != null && selectedStrategies.isNotEmpty()
            else -> false
        }
}