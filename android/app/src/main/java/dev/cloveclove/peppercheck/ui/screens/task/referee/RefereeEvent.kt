package dev.cloveclove.peppercheck.ui.screens.task.referee

sealed class RefereeEvent {
    data class LoadTask(val taskId: String) : RefereeEvent()
    data object RefreshTask : RefereeEvent()
    
    data object EditJudgementClicked : RefereeEvent()
    data object CancelEditJudgementClicked : RefereeEvent()
    data class JudgementStatusSelected(val status: String) : RefereeEvent()
    data class JudgementCommentChanged(val comment: String) : RefereeEvent()
    data object SubmitJudgementClicked : RefereeEvent()
    data object ConfirmEvidenceTimeoutClicked : RefereeEvent()
}