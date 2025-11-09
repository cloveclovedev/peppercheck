package dev.cloveclove.peppercheck.ui.screens.profile

import com.stripe.android.paymentsheet.PaymentSheetResult
import java.time.LocalTime

sealed class ProfileEvent {
    data object LoadData : ProfileEvent()
    data object RefreshData : ProfileEvent()
    data object CreateConnectLink : ProfileEvent()
    data object ConnectLinkHandled : ProfileEvent()
    data object SetupPaymentMethodClicked : ProfileEvent()
    data object PaymentSheetLaunchHandled : ProfileEvent()
    data class PaymentSheetLaunchFailed(val message: String) : ProfileEvent()
    data class PaymentSheetResultReceived(val result: PaymentSheetResult) : ProfileEvent()
    data object AddTimeSlotClicked : ProfileEvent()
    data object AddTimeSlotDialogDismissed : ProfileEvent()
    data class DayOfWeekSelected(val day: Int) : ProfileEvent()
    data class StartTimeSelected(val time: LocalTime) : ProfileEvent()
    data class EndTimeSelected(val time: LocalTime) : ProfileEvent()
    data object AddTimeSlotConfirmed : ProfileEvent()
    data class DeleteTimeSlot(val timeSlotId: String) : ProfileEvent()
}
