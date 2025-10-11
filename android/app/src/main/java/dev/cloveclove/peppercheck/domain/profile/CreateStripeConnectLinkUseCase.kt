package dev.cloveclove.peppercheck.domain.profile

import dev.cloveclove.peppercheck.repository.ProfileRepository

class CreateStripeConnectLinkUseCase(
    private val profileRepository: ProfileRepository
) {
    suspend operator fun invoke(): Result<String> {
        // Stripe Connect Link作成のロジックはProfileRepositoryに移動することを想定
        return profileRepository.createConnectLink()
    }
}