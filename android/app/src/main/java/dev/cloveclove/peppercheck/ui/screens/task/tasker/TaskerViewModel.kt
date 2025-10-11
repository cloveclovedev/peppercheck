package dev.cloveclove.peppercheck.ui.screens.task.tasker

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.cloveclove.peppercheck.domain.task.*
import dev.cloveclove.peppercheck.domain.rating.SubmitRefereeRatingUseCase
import dev.cloveclove.peppercheck.domain.rating.SubmitRefereeRatingParams
import dev.cloveclove.peppercheck.domain.judgement.ReopenJudgementUseCase
import dev.cloveclove.peppercheck.domain.judgement.ConfirmRefereeTimeoutJudgementUseCase
import dev.cloveclove.peppercheck.ui.screens.task.shared.toUiModel
import dev.cloveclove.peppercheck.ui.screens.task.shared.JudgementUiModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val TAG = "TaskerViewModel"

class TaskerViewModel(
    private val getTaskDetailsUseCase: GetTaskDetailsUseCase,
    private val updateTaskUseCase: UpdateTaskUseCase,
    private val submitEvidenceUseCase: SubmitEvidenceUseCase,
    private val submitRefereeRatingUseCase: SubmitRefereeRatingUseCase,
    private val confirmJudgementUseCase: ConfirmJudgementUseCase,
    private val confirmRefereeTimeoutJudgementUseCase: ConfirmRefereeTimeoutJudgementUseCase,
    private val closeTaskUseCase: CloseTaskUseCase,
    private val reopenJudgementUseCase: ReopenJudgementUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(TaskerUiState())
    val uiState = _uiState.asStateFlow()
    private var currentTaskId: String? = null

    fun onEvent(event: TaskerEvent) {
        when (event) {
            // データ読み込み
            is TaskerEvent.LoadTask -> {
                currentTaskId = event.taskId
                loadTaskDetails()
            }
            TaskerEvent.RefreshTask -> loadTaskDetails()

            // タスク編集関連
            TaskerEvent.EditTaskClicked -> enterEditTaskMode()
            TaskerEvent.CancelEditTaskClicked -> _uiState.update { it.copy(isEditingTask = false) }
            TaskerEvent.SaveTaskClicked -> saveTask()
            is TaskerEvent.TitleChanged -> {
                _uiState.update {
                    it.copy(editTaskForm = it.editTaskForm.copy(title = event.value))
                }
            }
            is TaskerEvent.DescriptionChanged -> {
                _uiState.update {
                    it.copy(editTaskForm = it.editTaskForm.copy(description = event.value))
                }
            }
            is TaskerEvent.CriteriaChanged -> {
                _uiState.update {
                    it.copy(editTaskForm = it.editTaskForm.copy(criteria = event.value))
                }
            }
            is TaskerEvent.StatusChanged -> {
                _uiState.update {
                    it.copy(editTaskForm = it.editTaskForm.copy(taskStatus = event.status))
                }
            }
            is TaskerEvent.StrategiesChanged -> {
                _uiState.update {
                    it.copy(editTaskForm = it.editTaskForm.copy(selectedStrategies = event.value))
                }
            }
            TaskerEvent.DateTimeClicked -> {
                _uiState.update { it.copy(isDatePickerVisible = true) }
            }
            TaskerEvent.DatePickerDismissed -> {
                _uiState.update { it.copy(isDatePickerVisible = false) }
            }
            TaskerEvent.TimePickerDismissed -> {
                _uiState.update { it.copy(isTimePickerVisible = false) }
            }
            TaskerEvent.DateSelected -> {
                _uiState.update { 
                    it.copy(
                        isDatePickerVisible = false,
                        isTimePickerVisible = true
                    )
                }
            }
            is TaskerEvent.TimeSelected -> {
                _uiState.update { 
                    it.copy(
                        isTimePickerVisible = false,
                        editTaskForm = it.editTaskForm.copy(selectedDateTime = event.dateTime)
                    )
                }
            }

            // エビデンス編集関連
            TaskerEvent.EditEvidenceClicked -> enterEditEvidenceMode()
            TaskerEvent.CancelEditEvidenceClicked -> _uiState.update { 
                it.copy(
                    isEditingEvidence = false,
                    evidenceForm = EvidenceFormState()
                ) 
            }
            is TaskerEvent.EvidenceDescriptionChanged -> {
                _uiState.update { 
                    it.copy(evidenceForm = it.evidenceForm.copy(description = event.value)) 
                }
            }
            is TaskerEvent.ImagesSelected -> {
                _uiState.update {
                    val currentCount = it.evidenceForm.totalImageCount
                    val remainingSpace = 5 - currentCount
                    val imagesToAdd = event.uris.take(remainingSpace)
                    it.copy(evidenceForm = it.evidenceForm.copy(
                        newlyAddedImageUris = it.evidenceForm.newlyAddedImageUris + imagesToAdd
                    ))
                }
            }
            is TaskerEvent.InitialImageRemoved -> {
                _uiState.update {
                    it.copy(evidenceForm = it.evidenceForm.copy(
                        initialImageUrls = it.evidenceForm.initialImageUrls - event.url
                    ))
                }
            }
            is TaskerEvent.NewImageUriRemoved -> {
                _uiState.update {
                    it.copy(evidenceForm = it.evidenceForm.copy(
                        newlyAddedImageUris = it.evidenceForm.newlyAddedImageUris - event.uri
                    ))
                }
            }
            TaskerEvent.SubmitEvidenceClicked -> submitEvidence()
            
            // 評価関連のイベント（旧実装）
            is TaskerEvent.JudgementCardClicked -> {
                _uiState.update { it.copy(ratingDialogState = RatingDialogState(isVisible = true, targetJudgement = event.judgement)) }
            }
            TaskerEvent.RatingDialogDismissed -> {
                _uiState.update { it.copy(ratingDialogState = RatingDialogState(isVisible = false)) } 
            }
            is TaskerEvent.RatingChanged -> {
                _uiState.update { it.copy(ratingDialogState = it.ratingDialogState.copy(rating = event.rating)) }
            }
            is TaskerEvent.RatingCommentChanged -> {
                _uiState.update { it.copy(ratingDialogState = it.ratingDialogState.copy(comment = event.comment)) }
            }
            TaskerEvent.SubmitRatingClicked -> submitRating()
            
            // Judgement確認関連のイベント（新実装）
            is TaskerEvent.ConfirmJudgementClicked -> {
                // タイムアウトケースでは直接confirm、それ以外はratingダイアログを表示
                if (event.judgement.status in listOf("judgement_timeout", "evidence_timeout")) {
                    confirmTimeoutJudgement(event.judgement)
                } else {
                    _uiState.update { it.copy(confirmJudgementDialogState = ConfirmJudgementDialogState(isVisible = true, targetJudgement = event.judgement)) }
                }
            }
            TaskerEvent.ConfirmJudgementDialogDismissed -> {
                _uiState.update { it.copy(confirmJudgementDialogState = ConfirmJudgementDialogState(isVisible = false)) }
            }
            is TaskerEvent.ConfirmJudgementRatingChanged -> {
                _uiState.update { it.copy(confirmJudgementDialogState = it.confirmJudgementDialogState.copy(rating = event.rating)) }
            }
            is TaskerEvent.ConfirmJudgementCommentChanged -> {
                _uiState.update { it.copy(confirmJudgementDialogState = it.confirmJudgementDialogState.copy(comment = event.comment)) }
            }
            TaskerEvent.SubmitJudgementConfirmationClicked -> submitJudgementConfirmation()
            
            // Judgement再開関連のイベント
            is TaskerEvent.ReopenJudgementClicked -> reopenJudgement(event.judgement)
            
            TaskerEvent.CloseTaskClicked -> closeTask()
        }
    }

    private fun loadTaskDetails() {
        val taskId = currentTaskId ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            getTaskDetailsUseCase(taskId)
                .onSuccess { details ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            task = details.task,
                            evidence = details.evidence,
                            judgements = details.judgements.map { j -> j.toUiModel() },
                            userRole = details.userRole
                        )
                    }
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to load task details for taskId: $taskId", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }

    private fun enterEditTaskMode() {
        _uiState.value.task?.let { task ->
            val selectedDateTime = task.dueDate?.let { dueDateString ->
                runCatching {
                    java.time.ZonedDateTime.parse(dueDateString)
                        .withZoneSameInstant(java.time.ZoneId.systemDefault())
                        .toLocalDateTime()
                }.getOrNull()
            }

            _uiState.update {
                it.copy(
                    isEditingTask = true,
                    editTaskForm = EditTaskFormState(
                        title = task.title,
                        description = task.description ?: "",
                        criteria = task.criteria ?: "",
                        selectedDateTime = selectedDateTime,
                        taskStatus = task.status
                    )
                )
            }
        }
    }

    private fun enterEditEvidenceMode() {
        _uiState.value.evidence?.let { evidence ->
            _uiState.update {
                it.copy(
                    isEditingEvidence = true,
                    evidenceForm = EvidenceFormState(
                        description = evidence.description,
                        initialImageUrls = evidence.taskEvidenceAssets.mapNotNull { asset -> asset.publicUrl },
                        newlyAddedImageUris = emptyList()
                    )
                )
            }
        }
    }

    private fun saveTask() {
        val taskId = currentTaskId ?: return
        val previousStatus = _uiState.value.task?.status ?: "draft"
        val formState = _uiState.value.editTaskForm
        
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val dueDateUtcString = formState.selectedDateTime
                ?.atZone(java.time.ZoneId.systemDefault())
                ?.toInstant()
                ?.toString()

            val params = UpdateTaskParams(
                taskId = taskId,
                title = formState.title,
                description = formState.description,
                criteria = formState.criteria,
                dueDate = dueDateUtcString,
                status = formState.taskStatus,
                previousStatus = previousStatus,
                selectedStrategies = formState.selectedStrategies
            )
            updateTaskUseCase(params)
                .onSuccess {
                    _uiState.update { it.copy(isEditingTask = false) }
                    loadTaskDetails()
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to save task for taskId: $taskId", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }

    private fun submitEvidence() {
        val taskId = currentTaskId ?: return
        val uiState = _uiState.value
        val form = uiState.evidenceForm
        
        // ★ ViewModel内のバリデーションが不要になり、Stateのプロパティを参照するだけになる
        if (!form.isSubmitEnabled) return
        
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            // 差分を計算
            val originalAssets = uiState.evidence?.taskEvidenceAssets ?: emptyList()
            val urlsToKeep = form.initialImageUrls
            
            // 削除対象のアセットIDを特定
            val assetIdsToDelete = originalAssets
                .filter { asset -> asset.publicUrl !in urlsToKeep }
                .map { asset -> asset.id }

            val params = SubmitEvidenceParams(
                taskId = taskId,
                evidenceId = uiState.evidence?.id,
                description = form.description,
                assetIdsToDelete = assetIdsToDelete,
                newImageUris = form.newlyAddedImageUris
            )
            submitEvidenceUseCase(params)
                .onSuccess {
                    _uiState.update { 
                        it.copy(
                            isEditingEvidence = false, 
                            evidenceForm = EvidenceFormState()
                        ) 
                    }
                    loadTaskDetails()
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to submit evidence for taskId: $taskId", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }

    private fun submitRating() {
        val taskId = currentTaskId ?: return
        val dialogState = _uiState.value.ratingDialogState
        val targetJudgement = dialogState.targetJudgement ?: return

        Log.d(TAG, "Submitting rating - taskId: $taskId, judgementId: ${targetJudgement.id}, refereeId: ${targetJudgement.refereeId}, rating: ${dialogState.rating}")

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, ratingDialogState = RatingDialogState(isVisible = false)) }
            
            val params = SubmitRefereeRatingParams(
                taskId = taskId,
                refereeId = targetJudgement.refereeId,
                judgementId = targetJudgement.id,
                rating = dialogState.rating,
                comment = dialogState.comment.takeIf { it.isNotBlank() }
            )
            
            submitRefereeRatingUseCase(params)
                .onSuccess {
                    Log.d(TAG, "Rating submitted successfully")
                    loadTaskDetails()
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to submit rating for judgement: ${targetJudgement.id}", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }

    private fun confirmTimeoutJudgement(judgement: JudgementUiModel) {
        Log.d(TAG, "Confirming timeout judgement - judgementId: ${judgement.id}, status: ${judgement.status}")

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            confirmRefereeTimeoutJudgementUseCase(judgement.id)
                .onSuccess {
                    Log.d(TAG, "Timeout judgement confirmed successfully")
                    loadTaskDetails()
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to confirm timeout judgement: ${judgement.id}", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }

    private fun submitJudgementConfirmation() {
        val taskId = currentTaskId ?: return
        val dialogState = _uiState.value.confirmJudgementDialogState
        val targetJudgement = dialogState.targetJudgement ?: return

        Log.d(TAG, "Confirming judgement - taskId: $taskId, judgementId: ${targetJudgement.id}, refereeId: ${targetJudgement.refereeId}, rating: ${dialogState.rating}")

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, confirmJudgementDialogState = ConfirmJudgementDialogState(isVisible = false)) }
            
            val params = ConfirmJudgementParams(
                taskId = taskId,
                judgementId = targetJudgement.id,
                rateeId = targetJudgement.refereeId,
                rating = dialogState.rating,
                comment = dialogState.comment.takeIf { it.isNotBlank() }
            )
            
            confirmJudgementUseCase(params)
                .onSuccess {
                    Log.d(TAG, "Judgement confirmed successfully")
                    loadTaskDetails()
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to confirm judgement: ${targetJudgement.id}", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }

    private fun closeTask() {
        val taskId = currentTaskId ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            closeTaskUseCase(taskId)
                .onSuccess { loadTaskDetails() }
                .onFailure { error -> 
                    Log.e(TAG, "Failed to close task: $taskId", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }

    private fun reopenJudgement(judgement: JudgementUiModel) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            reopenJudgementUseCase(judgement.id)
                .onSuccess { 
                    Log.d(TAG, "Successfully reopened judgement: ${judgement.id}")
                    loadTaskDetails() 
                }
                .onFailure { error -> 
                    Log.e(TAG, "Failed to reopen judgement: ${judgement.id}", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }
}
