package dev.cloveclove.peppercheck.ui.screens.create_task

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.cloveclove.peppercheck.domain.task.CreateTaskParams
import dev.cloveclove.peppercheck.domain.task.CreateTaskUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val TAG = "CreateTaskViewModel"

class CreateTaskViewModel(
    private val createTaskUseCase: CreateTaskUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(CreateTaskUiState())
    val uiState = _uiState.asStateFlow()

    fun onEvent(event: CreateTaskEvent) {
        when (event) {
            is CreateTaskEvent.TitleChanged -> _uiState.update { it.copy(title = event.value) }
            is CreateTaskEvent.DescriptionChanged -> _uiState.update { it.copy(description = event.value) }
            is CreateTaskEvent.CriteriaChanged -> _uiState.update { it.copy(criteria = event.value) }
            is CreateTaskEvent.StatusChanged -> _uiState.update { it.copy(taskStatus = event.value) }
            is CreateTaskEvent.StrategiesChanged -> _uiState.update { it.copy(selectedStrategies = event.value) }
            
            CreateTaskEvent.DateTimeClicked -> _uiState.update { it.copy(isDatePickerVisible = true) }
            CreateTaskEvent.DatePickerDismissed -> _uiState.update { it.copy(isDatePickerVisible = false) }
            CreateTaskEvent.DateSelected -> _uiState.update { it.copy(isDatePickerVisible = false, isTimePickerVisible = true) }
            is CreateTaskEvent.TimeSelected -> _uiState.update { it.copy(selectedDateTime = event.dateTime, isTimePickerVisible = false) }
            CreateTaskEvent.TimePickerDismissed -> _uiState.update { it.copy(isTimePickerVisible = false) }
            
            CreateTaskEvent.CreateTaskClicked -> createTask()
            CreateTaskEvent.SuccessMessageConsumed -> _uiState.update { it.copy(isSuccess = false) }
        }
    }

    private fun createTask() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            val currentState = _uiState.value
            val dueDateString = currentState.selectedDateTime?.atZone(java.time.ZoneId.systemDefault())
                ?.toInstant()
                ?.toString()
            
            val params = CreateTaskParams(
                title = currentState.title,
                description = currentState.description.takeIf { it.isNotBlank() },
                criteria = currentState.criteria.takeIf { it.isNotBlank() },
                dueDate = dueDateString,
                feeAmount = (currentState.selectedStrategies.size * 50.0),
                status = currentState.taskStatus,
                selectedStrategies = currentState.selectedStrategies
            )

            createTaskUseCase(params)
                .onSuccess {
                    _uiState.update { it.copy(isLoading = false, isSuccess = true) }
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to create task", error)
                    _uiState.update { it.copy(isLoading = false, error = error.message ?: "Unknown error") }
                }
        }
    }
}