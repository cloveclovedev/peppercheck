package dev.cloveclove.peppercheck.domain.task

import dev.cloveclove.peppercheck.domain.rating.RatingRepository
import dev.cloveclove.peppercheck.repository.*

class GetTaskDetailsUseCase(
    private val taskRepository: TaskRepository,
    private val taskEvidenceRepository: TaskEvidenceRepository,
    private val judgementRepository: JudgementRepository,
    private val taskRefereeRequestRepository: TaskRefereeRequestRepository,
    private val ratingRepository: RatingRepository,
    private val authRepository: AuthRepository
) {
    suspend operator fun invoke(taskId: String): Result<TaskDetails> {
        return runCatching {
            val task = taskRepository.getTaskById(taskId).getOrThrow()
            val evidence = taskEvidenceRepository.getTaskEvidence(taskId).getOrNull()
            val judgements = judgementRepository.getJudgements(taskId).getOrThrow()
            val refereeRequests = taskRefereeRequestRepository.getTaskRefereeRequests(taskId).getOrThrow()
            
            val currentUserId = authRepository.getCurrentUserId()

            val userRole = when {
                currentUserId == task.taskerId -> UserRole.TASKER
                refereeRequests.any { it.matchedRefereeId == currentUserId && it.status in listOf("matched", "accepted") } -> UserRole.REFEREE
                else -> UserRole.UNKNOWN
            }
            
            val ratingsByTasker = ratingRepository.getRatingsByTaskerForTask(taskId).getOrThrow()
            
            val myJudgement = judgements.firstOrNull()

            TaskDetails(
                task = task,
                evidence = evidence,
                judgements = judgements,
                myJudgement = myJudgement,
                refereeRequests = refereeRequests,
                ratingsByTasker = ratingsByTasker,
                userRole = userRole
            )
        }
    }
}