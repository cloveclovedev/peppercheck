package dev.cloveclove.peppercheck.domain.task

import dev.cloveclove.peppercheck.repository.TaskRepository

class CloseTaskUseCase(
    private val taskRepository: TaskRepository
) {
    suspend operator fun invoke(taskId: String): Result<Unit> {
        return taskRepository.updateTask(
            taskId = taskId,
            status = "closed"
        ).map { }
    }
}