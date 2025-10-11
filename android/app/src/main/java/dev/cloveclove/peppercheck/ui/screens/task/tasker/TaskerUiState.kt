package dev.cloveclove.peppercheck.ui.screens.task.tasker

import android.net.Uri
import dev.cloveclove.peppercheck.data.evidence.TaskEvidence
import dev.cloveclove.peppercheck.data.task.Task
import dev.cloveclove.peppercheck.domain.task.UserRole
import dev.cloveclove.peppercheck.ui.screens.task.shared.JudgementUiModel
import java.time.LocalDateTime

data class EditTaskFormState(
    val title: String = "",
    val description: String = "",
    val criteria: String = "",
    val selectedDateTime: LocalDateTime? = null,
    val taskStatus: String = "draft",
    val selectedStrategies: List<String> = emptyList()
) {
    /**
     * 現在のフォーム入力内容に基づいて、保存ボタンが有効かどうかを判定します。
     */
    val isFormValid: Boolean
        get() = when (taskStatus) {
            "draft" -> title.isNotBlank()
            "open" -> title.isNotBlank() && criteria.isNotBlank() && selectedDateTime != null && selectedStrategies.isNotEmpty()
            else -> false // "judging", "completed" など他のステータスは編集不可
        }
}

// --- Evidence提出フォームの状態とバリデーション ---
data class EvidenceFormState(
    val description: String = "",
    val initialImageUrls: List<String> = emptyList(),
    val newlyAddedImageUris: List<Uri> = emptyList()
) {
    val totalImageCount: Int
        get() = initialImageUrls.size + newlyAddedImageUris.size
        
    val isSubmitEnabled: Boolean
        get() = description.isNotBlank() && totalImageCount > 0
}

data class RatingDialogState(
    val isVisible: Boolean = false,
    val targetJudgement: JudgementUiModel? = null,
    val rating: Int = 0,
    val comment: String = ""
) {
    val isSubmitEnabled: Boolean
        get() = rating > 0
}

data class ConfirmJudgementDialogState(
    val isVisible: Boolean = false,
    val targetJudgement: JudgementUiModel? = null,
    val rating: Int = 0,
    val comment: String = ""
) {
    val isSubmitEnabled: Boolean
        get() = rating > 0
}

data class TaskerUiState(
    val task: Task? = null,
    val evidence: TaskEvidence? = null,
    val judgements: List<JudgementUiModel> = emptyList(),
    val userRole: UserRole = UserRole.UNKNOWN,

    val isLoading: Boolean = true,
    val error: String? = null,
    val isDatePickerVisible: Boolean = false,
    val isTimePickerVisible: Boolean = false,

    val isEditingTask: Boolean = false,
    val isEditingEvidence: Boolean = false,

    // ★ フォームごとにStateを分離
    val editTaskForm: EditTaskFormState = EditTaskFormState(),
    val evidenceForm: EvidenceFormState = EvidenceFormState(),
    
    val ratingDialogState: RatingDialogState = RatingDialogState(),
    val confirmJudgementDialogState: ConfirmJudgementDialogState = ConfirmJudgementDialogState()
) {
    val areAllJudgementsApproved: Boolean
        get() = judgements.isNotEmpty() && judgements.all { it.status == "approved" }
    
    val canBeClosed: Boolean
        get() = judgements.isNotEmpty() && judgements.all { it.isConfirmed }
}
