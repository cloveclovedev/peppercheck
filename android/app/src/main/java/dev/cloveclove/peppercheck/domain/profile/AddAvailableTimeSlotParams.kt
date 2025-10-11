package dev.cloveclove.peppercheck.domain.profile

data class AddAvailableTimeSlotParams(
    val dayOfWeek: Int,
    val startMin: Int,
    val endMin: Int
)