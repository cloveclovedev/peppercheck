package dev.cloveclove.peppercheck.ui.screens.task.referee

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.cloveclove.peppercheck.domain.task.GetTaskDetailsUseCase
import dev.cloveclove.peppercheck.domain.task.UpdateJudgementParams
import dev.cloveclove.peppercheck.domain.task.UpdateJudgementUseCase
import dev.cloveclove.peppercheck.domain.judgement.ConfirmEvidenceTimeoutFromRefereeUseCase
import dev.cloveclove.peppercheck.ui.screens.task.shared.toUiModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

private const val TAG = "RefereeViewModel"

class RefereeViewModel(
    private val getTaskDetailsUseCase: GetTaskDetailsUseCase,
    private val updateJudgementUseCase: UpdateJudgementUseCase,
    private val confirmEvidenceTimeoutFromRefereeUseCase: ConfirmEvidenceTimeoutFromRefereeUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(RefereeUiState())
    val uiState = _uiState.asStateFlow()
    private var currentTaskId: String? = null

    fun onEvent(event: RefereeEvent) {
        when (event) {
            is RefereeEvent.LoadTask -> {
                currentTaskId = event.taskId
                loadTaskDetails()
            }
            RefereeEvent.RefreshTask -> loadTaskDetails()
            RefereeEvent.EditJudgementClicked -> enterEditJudgementMode()
            RefereeEvent.CancelEditJudgementClicked -> _uiState.update { it.copy(isEditingJudgement = false) }
            is RefereeEvent.JudgementStatusSelected -> _uiState.update { 
                it.copy(judgementForm = it.judgementForm.copy(status = event.status)) 
            }
            is RefereeEvent.JudgementCommentChanged -> _uiState.update { 
                it.copy(judgementForm = it.judgementForm.copy(comment = event.comment)) 
            }
            RefereeEvent.SubmitJudgementClicked -> submitJudgement()
            RefereeEvent.ConfirmEvidenceTimeoutClicked -> confirmEvidenceTimeout()
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
                            myJudgement = details.myJudgement?.toUiModel()
                        )
                    }
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to load task details for taskId: $taskId", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }

    private fun enterEditJudgementMode() {
        _uiState.value.myJudgement?.let { judgement ->
            _uiState.update {
                it.copy(
                    isEditingJudgement = true,
                    judgementForm = JudgementFormState(
                        comment = judgement.comment ?: "",
                        status = judgement.status
                    )
                )
            }
        }
    }

    private fun submitJudgement() {
        val judgementId = _uiState.value.myJudgement?.id ?: return
        val form = _uiState.value.judgementForm
        
        // ★ ViewModel内のバリデーションは不要になる
        if (!form.isSubmitEnabled) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            val params = UpdateJudgementParams(
                judgementId = judgementId,
                status = form.status!!, // isSubmitEnabledでnullでないことが保証されている
                comment = form.comment
            )
            updateJudgementUseCase(params)
                .onSuccess {
                    _uiState.update { it.copy(isEditingJudgement = false) }
                    loadTaskDetails()
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to submit judgement for judgementId: $judgementId", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }

    private fun confirmEvidenceTimeout() {
        val judgementId = _uiState.value.myJudgement?.id ?: return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            confirmEvidenceTimeoutFromRefereeUseCase(judgementId)
                .onSuccess {
                    loadTaskDetails()
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to confirm evidence timeout for judgementId: $judgementId", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }
}