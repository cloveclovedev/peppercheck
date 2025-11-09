package dev.cloveclove.peppercheck.domain.profile

import dev.cloveclove.peppercheck.data.stripe.StripePaymentSetupSession
import dev.cloveclove.peppercheck.repository.StripeRepository

class CreateStripePaymentSetupSessionUseCase(
    private val stripeRepository: StripeRepository
) {
    suspend operator fun invoke(): Result<StripePaymentSetupSession> {
        return stripeRepository.createPaymentSetupSession()
    }
}
