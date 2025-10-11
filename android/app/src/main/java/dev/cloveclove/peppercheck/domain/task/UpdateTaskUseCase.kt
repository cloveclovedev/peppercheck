package dev.cloveclove.peppercheck.domain.task

import dev.cloveclove.peppercheck.data.task.Task
import dev.cloveclove.peppercheck.repository.TaskRepository
import dev.cloveclove.peppercheck.repository.TaskRefereeRequestRepository

class UpdateTaskUseCase(
    private val taskRepository: TaskRepository,
    private val taskRefereeRequestRepository: TaskRefereeRequestRepository
) {
    suspend operator fun invoke(params: UpdateTaskParams): Result<Task> {
        return runCatching {
            val totalFee = params.selectedStrategies.size * 50.0

            val updatedTask = taskRepository.updateTask(
                taskId = params.taskId,
                title = params.title,
                description = params.description,
                criteria = params.criteria,
                dueDate = params.dueDate,
                feeAmount = totalFee,
                status = params.status
            ).getOrThrow()
            
            if (params.previousStatus == "draft" && params.status == "open" && params.selectedStrategies.isNotEmpty()) {
                params.selectedStrategies.forEach { strategy ->
                    taskRefereeRequestRepository.createTaskRefereeRequest(
                        taskId = params.taskId,
                        matchingStrategy = strategy
                    ).getOrThrow()
                }
            }

            updatedTask
        }
    }
}
