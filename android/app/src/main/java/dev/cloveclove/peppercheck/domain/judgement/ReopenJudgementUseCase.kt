package dev.cloveclove.peppercheck.domain.judgement

import dev.cloveclove.peppercheck.repository.JudgementRepository

class ReopenJudgementUseCase(
    private val judgementRepository: JudgementRepository
) {
    suspend operator fun invoke(judgementId: String): Result<Unit> {
        return judgementRepository.reopenJudgement(judgementId)
    }
}