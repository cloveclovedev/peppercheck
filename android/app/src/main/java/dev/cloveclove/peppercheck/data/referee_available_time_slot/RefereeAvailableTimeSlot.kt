package dev.cloveclove.peppercheck.data.referee_available_time_slot

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RefereeAvailableTimeSlot(
    val id: String,
    @SerialName("user_id") 
    val userId: String,
    val dow: Int, // 0=Sunday, 6=Saturday
    @SerialName("start_min") 
    val startMin: Int, // Minutes from midnight (0-1439)
    @SerialName("end_min") 
    val endMin: Int,   // Minutes from midnight (1-1440)
    @SerialName("is_active") 
    val isActive: Boolean = true,
    @SerialName("created_at") 
    val createdAt: String,
    @SerialName("updated_at") 
    val updatedAt: String? = null
) {
    fun getDayName(): String {
        return when (dow) {
            0 -> "Sunday"
            1 -> "Monday"
            2 -> "Tuesday"
            3 -> "Wednesday"
            4 -> "Thursday"
            5 -> "Friday"
            6 -> "Saturday"
            else -> "Unknown"
        }
    }
    
    fun getFormattedTime(): String {
        val startHour = startMin / 60
        val startMinute = startMin % 60
        val endHour = endMin / 60
        val endMinute = endMin % 60
        
        return "%02d:%02d - %02d:%02d".format(startHour, startMinute, endHour, endMinute)
    }
    
    fun getDisplayText(): String {
        return "${getDayName()}: ${getFormattedTime()}"
    }
    
    /**
     * Check if this availability overlaps with another availability
     */
    fun overlapsWith(other: RefereeAvailableTimeSlot): Boolean {
        return dow == other.dow && 
               startMin < other.endMin && 
               endMin > other.startMin
    }
    
    companion object {
        // Helper functions to convert between UI time and minutes
        fun timeToMinutes(hour: Int, minute: Int): Int {
            return hour * 60 + minute
        }
        
        fun minutesToHour(minutes: Int): Int {
            return minutes / 60
        }
        
        fun minutesToMinute(minutes: Int): Int {
            return minutes % 60
        }
        
        /**
         * Check if a new availability would overlap with existing ones
         */
        fun hasOverlap(
            existingAvailabilities: List<RefereeAvailableTimeSlot>,
            newDow: Int,
            newStartMin: Int,
            newEndMin: Int
        ): Boolean {
            val newAvailability = RefereeAvailableTimeSlot(
                id = "", userId = "", dow = newDow, startMin = newStartMin, 
                endMin = newEndMin, isActive = true, createdAt = "", updatedAt = null
            )
            
            return existingAvailabilities.any { it.overlapsWith(newAvailability) }
        }
    }
}


