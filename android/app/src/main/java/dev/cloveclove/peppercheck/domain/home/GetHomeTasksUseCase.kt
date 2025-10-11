package dev.cloveclove.peppercheck.domain.home

import dev.cloveclove.peppercheck.data.task.Task
import dev.cloveclove.peppercheck.repository.TaskRepository

data class HomeTasks(
    val userTasks: List<Task>,
    val refereeTasks: List<Task>
)

class GetHomeTasksUseCase(
    private val taskRepository: TaskRepository
) {
    suspend operator fun invoke(): Result<HomeTasks> {
        return runCatching {
            val userTasksResult = taskRepository.getActiveUserTasks()
            val refereeTasksResult = taskRepository.getActiveRefereeTasks()

            val userTasks = userTasksResult.getOrThrow()
            val refereeTasks = refereeTasksResult.getOrThrow()

            // TODO: checkAndUpdateTasksCompletionのロジックをここに移動させるのが理想
            // val updatedUserTasks = taskRepository.checkAndUpdateTasksCompletion(userTasks)

            HomeTasks(
                userTasks = userTasks, // 本来は updatedUserTasks
                refereeTasks = refereeTasks
            )
        }
    }
}