package dev.cloveclove.peppercheck.ui.screens.home

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.cloveclove.peppercheck.domain.home.GetHomeTasksUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val TAG = "HomeViewModel"

class HomeViewModel(
    private val getHomeTasksUseCase: GetHomeTasksUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState = _uiState.asStateFlow()

    init {
        onEvent(HomeScreenEvent.LoadTasks)
    }

    fun onEvent(event: HomeScreenEvent) {
        when (event) {
            HomeScreenEvent.LoadTasks -> loadTasks()
            HomeScreenEvent.RefreshTasks -> loadTasks()
        }
    }

    private fun loadTasks() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }

            getHomeTasksUseCase()
                .onSuccess { homeTasks ->
                    _uiState.update {
                        it.copy(
                            yourTasks = homeTasks.userTasks,
                            refereeTasks = homeTasks.refereeTasks,
                            isLoading = false
                        )
                    }
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to load home tasks", error)
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            errorMessage = error.message ?: "Failed to load tasks."
                        )
                    }
                }
        }
    }
}