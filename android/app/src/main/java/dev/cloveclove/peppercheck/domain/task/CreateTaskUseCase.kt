package dev.cloveclove.peppercheck.domain.task

import dev.cloveclove.peppercheck.data.task.Task
import dev.cloveclove.peppercheck.repository.TaskRepository
import dev.cloveclove.peppercheck.repository.TaskRefereeRequestRepository

class CreateTaskUseCase(
    private val taskRepository: TaskRepository,
    private val taskRefereeRequestRepository: TaskRefereeRequestRepository
) {
    suspend operator fun invoke(params: CreateTaskParams): Result<Task> {
        return runCatching {
            // 1. タスクを作成
            val task = taskRepository.createTask(
                title = params.title,
                description = params.description,
                criteria = params.criteria,
                dueDate = params.dueDate,
                feeAmount = params.feeAmount,
                status = params.status
            ).getOrThrow()

            // 2. 必要であればレフェリーリクエストを作成
            if (params.status == "open" && params.selectedStrategies.isNotEmpty()) {
                // UseCaseがビジネスロジック（ループ処理）を担当します。
                // 選択された各戦略に対して、リクエスト作成関数を呼び出します。
                params.selectedStrategies.forEach { strategy ->
                    taskRefereeRequestRepository.createTaskRefereeRequest(
                        taskId = task.id,
                        matchingStrategy = strategy
                    ).getOrThrow() // もし1件でも失敗したら、UseCase全体が失敗するようにします
                }
            }

            task
        }
    }
}