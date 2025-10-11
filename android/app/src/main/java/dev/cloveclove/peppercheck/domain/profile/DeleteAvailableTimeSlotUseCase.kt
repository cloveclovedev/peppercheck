package dev.cloveclove.peppercheck.domain.profile

import dev.cloveclove.peppercheck.repository.RefereeAvailableTimeSlotRepository

class DeleteAvailableTimeSlotUseCase(
    private val repository: RefereeAvailableTimeSlotRepository
) {
    suspend operator fun invoke(timeSlotId: String): Result<Unit> {
        return repository.deleteAvailableTimeSlot(timeSlotId)
    }
}