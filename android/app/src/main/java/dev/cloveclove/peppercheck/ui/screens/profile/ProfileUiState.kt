package dev.cloveclove.peppercheck.ui.screens.profile

import dev.cloveclove.peppercheck.data.referee_available_time_slot.RefereeAvailableTimeSlot
import dev.cloveclove.peppercheck.data.stripe.StripeAccount
import dev.cloveclove.peppercheck.data.stripe.StripePaymentSetupSession
import java.time.LocalTime

data class ProfileUiState(
    val availableTimeSlots: List<RefereeAvailableTimeSlot> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
    val connectLinkState: ConnectLinkState = ConnectLinkState.Idle,
    val stripeAccount: StripeAccount? = null,
    val isPaymentSheetInProgress: Boolean = false,
    val paymentSheetSetupData: StripePaymentSetupSession? = null,
    val paymentSheetMessage: String? = null,
    val paymentSheetError: String? = null,
    val isAddTimeSlotDialogVisible: Boolean = false,
    val dialogSelectedDay: Int = 1, // Monday
    val dialogStartTime: LocalTime = LocalTime.of(9, 0),
    val dialogEndTime: LocalTime = LocalTime.of(17, 0),
    val payoutAvailableMinor: Long? = null,
    val payoutPendingMinor: Long = 0,          // payout_jobs pending/processing
    val payoutIncomingPendingMinor: Long = 0,  // Stripe balance pending
    val payoutCurrency: String = "JPY",
    val isPayoutDialogVisible: Boolean = false,
    val payoutInputMinor: Long = 0,
    val isPayoutInProgress: Boolean = false,
    val payoutError: String? = null,
    val payoutMessage: String? = null
)

sealed class ConnectLinkState {
    object Idle : ConnectLinkState()
    object Loading : ConnectLinkState()
    data class Success(val url: String) : ConnectLinkState()
    data class Error(val message: String) : ConnectLinkState()
}
