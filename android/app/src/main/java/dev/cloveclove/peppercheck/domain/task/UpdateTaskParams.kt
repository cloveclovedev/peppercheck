package dev.cloveclove.peppercheck.domain.task

data class UpdateTaskParams(
    val taskId: String,
    val title: String,
    val description: String?,
    val criteria: String?,
    val dueDate: String?,
    val status: String,
    val previousStatus: String,
    val selectedStrategies: List<String>
)