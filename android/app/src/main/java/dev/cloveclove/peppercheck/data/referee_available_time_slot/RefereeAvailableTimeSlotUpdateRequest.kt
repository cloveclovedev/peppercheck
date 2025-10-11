package dev.cloveclove.peppercheck.data.referee_available_time_slot

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RefereeAvailableTimeSlotUpdateRequest(
    val dow: Int? = null,
    @SerialName("start_min")
    val startMin: Int? = null,
    @SerialName("end_min")
    val endMin: Int? = null,
    @SerialName("is_active")
    val isActive: Boolean? = null
)