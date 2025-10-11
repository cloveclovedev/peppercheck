package dev.cloveclove.peppercheck.domain.task

import dev.cloveclove.peppercheck.data.evidence.TaskEvidence
import dev.cloveclove.peppercheck.data.judgement.Judgement
import dev.cloveclove.peppercheck.data.rating.RatingHistory
import dev.cloveclove.peppercheck.data.referee_request.TaskRefereeRequest
import dev.cloveclove.peppercheck.data.task.Task

data class TaskDetails(
    val task: Task,
    val evidence: TaskEvidence?,
    val judgements: List<Judgement>,
    val myJudgement: Judgement?,
    val refereeRequests: List<TaskRefereeRequest>,
    val ratingsByTasker: List<RatingHistory>,
    val userRole: UserRole
)