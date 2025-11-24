package dev.cloveclove.peppercheck.domain.payout

import dev.cloveclove.peppercheck.repository.PayoutRepository

class GetPayoutSummaryUseCase(
    private val payoutRepository: PayoutRepository
) {
    suspend operator fun invoke() = payoutRepository.getPayoutSummary()
}
