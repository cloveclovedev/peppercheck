package dev.cloveclove.peppercheck.ui.screens.task.referee

import dev.cloveclove.peppercheck.data.evidence.TaskEvidence
import dev.cloveclove.peppercheck.data.task.Task
import dev.cloveclove.peppercheck.ui.screens.task.shared.JudgementUiModel

data class JudgementFormState(
    val comment: String = "",
    val status: String? = null
) {
    val isSubmitEnabled: Boolean
        get() = status != null && comment.isNotBlank()
}

data class RefereeUiState(
    val task: Task? = null,
    val evidence: TaskEvidence? = null,
    val myJudgement: JudgementUiModel? = null,

    val isLoading: Boolean = true,
    val error: String? = null,

    val isEditingJudgement: Boolean = false,

    val judgementForm: JudgementFormState = JudgementFormState()
)