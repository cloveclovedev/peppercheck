package dev.cloveclove.peppercheck.ui.screens.profile

import dev.cloveclove.peppercheck.data.referee_available_time_slot.RefereeAvailableTimeSlot
import java.time.LocalTime

data class ProfileUiState(
    val availableTimeSlots: List<RefereeAvailableTimeSlot> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
    val connectLinkState: ConnectLinkState = ConnectLinkState.Idle,
    val isAddTimeSlotDialogVisible: Boolean = false,
    val dialogSelectedDay: Int = 1, // Monday
    val dialogStartTime: LocalTime = LocalTime.of(9, 0),
    val dialogEndTime: LocalTime = LocalTime.of(17, 0)
)

sealed class ConnectLinkState {
    object Idle : ConnectLinkState()
    object Loading : ConnectLinkState()
    data class Success(val url: String) : ConnectLinkState()
    data class Error(val message: String) : ConnectLinkState()
}