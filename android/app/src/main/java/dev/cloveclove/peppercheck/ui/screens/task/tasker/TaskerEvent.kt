package dev.cloveclove.peppercheck.ui.screens.task.tasker

import android.net.Uri
import dev.cloveclove.peppercheck.ui.screens.task.shared.JudgementUiModel
import java.time.LocalDateTime

sealed class TaskerEvent {
    data class LoadTask(val taskId: String) : TaskerEvent()
    data object RefreshTask : TaskerEvent()
    
    data object EditTaskClicked : TaskerEvent()
    data object SaveTaskClicked : TaskerEvent()
    data object CancelEditTaskClicked : TaskerEvent()
    data class TitleChanged(val value: String) : TaskerEvent()
    data class DescriptionChanged(val value: String) : TaskerEvent()
    data class CriteriaChanged(val value: String) : TaskerEvent()
    data class StatusChanged(val status: String) : TaskerEvent()
    data class StrategiesChanged(val value: List<String>) : TaskerEvent()
    data object DateTimeClicked : TaskerEvent()
    data object DatePickerDismissed : TaskerEvent()
    data object TimePickerDismissed : TaskerEvent()
    data object DateSelected : TaskerEvent()
    data class TimeSelected(val dateTime: LocalDateTime) : TaskerEvent()

    data object EditEvidenceClicked : TaskerEvent()
    data object CancelEditEvidenceClicked : TaskerEvent()
    data class EvidenceDescriptionChanged(val value: String) : TaskerEvent()
    data class ImagesSelected(val uris: List<Uri>) : TaskerEvent()
    data class InitialImageRemoved(val url: String) : TaskerEvent() // URLを削除するイベント
    data class NewImageUriRemoved(val uri: Uri) : TaskerEvent()     // Uriを削除するイベント
    data object SubmitEvidenceClicked : TaskerEvent()
    
    // 評価関連のイベント
    data class JudgementCardClicked(val judgement: JudgementUiModel) : TaskerEvent()
    data object RatingDialogDismissed : TaskerEvent()
    data class RatingChanged(val rating: Int) : TaskerEvent()
    data class RatingCommentChanged(val comment: String) : TaskerEvent()
    data object SubmitRatingClicked : TaskerEvent()
    
    // Judgement確認関連のイベント
    data class ConfirmJudgementClicked(val judgement: JudgementUiModel) : TaskerEvent()
    data object ConfirmJudgementDialogDismissed : TaskerEvent()
    data class ConfirmJudgementRatingChanged(val rating: Int) : TaskerEvent()
    data class ConfirmJudgementCommentChanged(val comment: String) : TaskerEvent()
    data object SubmitJudgementConfirmationClicked : TaskerEvent()
    
    // Judgement再開関連のイベント
    data class ReopenJudgementClicked(val judgement: JudgementUiModel) : TaskerEvent()
    
    data object CloseTaskClicked : TaskerEvent()
}