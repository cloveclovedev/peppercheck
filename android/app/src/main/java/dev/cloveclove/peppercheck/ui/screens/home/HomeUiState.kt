package dev.cloveclove.peppercheck.ui.screens.home

import dev.cloveclove.peppercheck.data.task.Task

data class HomeUiState(
    val yourTasks: List<Task> = emptyList(),
    val refereeTasks: List<Task> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null
)