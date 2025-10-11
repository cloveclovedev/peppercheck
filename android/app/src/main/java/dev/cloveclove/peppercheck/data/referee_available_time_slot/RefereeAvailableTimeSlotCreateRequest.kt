package dev.cloveclove.peppercheck.data.referee_available_time_slot

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RefereeAvailableTimeSlotCreateRequest(
    @SerialName("user_id")
    val userId: String,
    val dow: Int,
    @SerialName("start_min")
    val startMin: Int,
    @SerialName("end_min")
    val endMin: Int,
    @SerialName("is_active")
    val isActive: Boolean = true
)