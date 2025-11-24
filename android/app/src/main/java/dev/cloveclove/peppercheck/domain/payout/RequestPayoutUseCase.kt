package dev.cloveclove.peppercheck.domain.payout

import dev.cloveclove.peppercheck.repository.PayoutRepository

class RequestPayoutUseCase(
    private val payoutRepository: PayoutRepository
) {
    suspend operator fun invoke(amountMinor: Long, currencyCode: String = "JPY") =
        payoutRepository.requestPayout(amountMinor, currencyCode)
}
