package dev.cloveclove.peppercheck.domain.judgement

import dev.cloveclove.peppercheck.repository.JudgementRepository

/**
 * Use case for confirming referee timeout judgements.
 * This is used specifically for judgement_timeout and evidence_timeout cases
 * where no manual rating is required (0-point rating is handled automatically by the database trigger).
 */
class ConfirmRefereeTimeoutJudgementUseCase(
    private val judgementRepository: JudgementRepository
) {
    suspend operator fun invoke(judgementId: String): Result<Unit> {
        return judgementRepository.confirmJudgement(judgementId)
    }
}