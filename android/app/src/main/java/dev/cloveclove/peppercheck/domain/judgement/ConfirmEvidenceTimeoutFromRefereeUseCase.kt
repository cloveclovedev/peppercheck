package dev.cloveclove.peppercheck.domain.judgement

import dev.cloveclove.peppercheck.repository.JudgementRepository

/**
 * Use case for confirming evidence timeout from referee.
 * This sets the is_evidence_timeout_confirmed flag to true,
 * which should trigger system processes to close the task_referee_request.
 */
class ConfirmEvidenceTimeoutFromRefereeUseCase(
    private val judgementRepository: JudgementRepository
) {
    suspend operator fun invoke(judgementId: String): Result<Unit> {
        return judgementRepository.confirmEvidenceTimeoutFromReferee(judgementId)
    }
}