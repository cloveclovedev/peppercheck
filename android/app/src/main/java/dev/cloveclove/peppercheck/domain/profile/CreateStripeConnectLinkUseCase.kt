package dev.cloveclove.peppercheck.domain.profile

import dev.cloveclove.peppercheck.repository.StripeRepository

class CreateStripeConnectLinkUseCase(
    private val stripeRepository: StripeRepository
) {
    suspend operator fun invoke(): Result<String> {
        return stripeRepository.createPayoutSetupLink()
    }
}
