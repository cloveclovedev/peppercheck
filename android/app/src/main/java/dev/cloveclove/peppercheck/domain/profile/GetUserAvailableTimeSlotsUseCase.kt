package dev.cloveclove.peppercheck.domain.profile

import dev.cloveclove.peppercheck.data.referee_available_time_slot.RefereeAvailableTimeSlot
import dev.cloveclove.peppercheck.repository.RefereeAvailableTimeSlotRepository

class GetUserAvailableTimeSlotsUseCase(
    private val repository: RefereeAvailableTimeSlotRepository
) {
    suspend operator fun invoke(): Result<List<RefereeAvailableTimeSlot>> {
        return repository.getUserAvailableTimeSlots()
    }
}