package dev.cloveclove.peppercheck.domain.profile

import dev.cloveclove.peppercheck.data.referee_available_time_slot.RefereeAvailableTimeSlot
import dev.cloveclove.peppercheck.repository.RefereeAvailableTimeSlotRepository

class AddAvailableTimeSlotUseCase(
    private val repository: RefereeAvailableTimeSlotRepository
) {
    suspend operator fun invoke(
        params: AddAvailableTimeSlotParams,
        currentTimeSlots: List<RefereeAvailableTimeSlot>
    ): Result<Unit> {
        // ビジネスロジック: 重複チェック
        val hasOverlap = currentTimeSlots.any { 
            it.dow == params.dayOfWeek && it.startMin < params.endMin && it.endMin > params.startMin
        }
        if (hasOverlap) {
            return Result.failure(Exception("This time slot overlaps with an existing one."))
        }
        
        // データの永続化はRepositoryに任せる
        return repository.createAvailableTimeSlot(
            dow = params.dayOfWeek,
            startMin = params.startMin,
            endMin = params.endMin
        ).map { } // Result<RefereeAvailableTimeSlot> を Result<Unit> に変換
    }
}