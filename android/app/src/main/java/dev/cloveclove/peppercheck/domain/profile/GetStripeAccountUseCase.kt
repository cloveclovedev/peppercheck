package dev.cloveclove.peppercheck.domain.profile

import dev.cloveclove.peppercheck.data.stripe.StripeAccount
import dev.cloveclove.peppercheck.repository.StripeRepository

class GetStripeAccountUseCase(
    private val stripeRepository: StripeRepository
) {
    suspend operator fun invoke(): Result<StripeAccount?> {
        return stripeRepository.getStripeAccount()
    }
}
