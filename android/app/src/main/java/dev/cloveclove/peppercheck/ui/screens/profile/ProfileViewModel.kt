package dev.cloveclove.peppercheck.ui.screens.profile

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.cloveclove.peppercheck.data.referee_available_time_slot.RefereeAvailableTimeSlot
import dev.cloveclove.peppercheck.domain.profile.*
import com.stripe.android.paymentsheet.PaymentSheetResult
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

private const val TAG = "ProfileViewModel"

class ProfileViewModel(
    private val getUserAvailableTimeSlotsUseCase: GetUserAvailableTimeSlotsUseCase,
    private val addAvailableTimeSlotUseCase: AddAvailableTimeSlotUseCase,
    private val deleteAvailableTimeSlotUseCase: DeleteAvailableTimeSlotUseCase,
    private val createStripeConnectLinkUseCase: CreateStripeConnectLinkUseCase,
    private val getStripeAccountUseCase: GetStripeAccountUseCase,
    private val createStripePaymentSetupSessionUseCase: CreateStripePaymentSetupSessionUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState = _uiState.asStateFlow()

    init { onEvent(ProfileEvent.LoadData) }

    fun onEvent(event: ProfileEvent) {
        when (event) {
            ProfileEvent.LoadData, ProfileEvent.RefreshData -> loadProfileData()
            ProfileEvent.CreateConnectLink -> createConnectLink()
            ProfileEvent.ConnectLinkHandled -> _uiState.update { it.copy(connectLinkState = ConnectLinkState.Idle) }
            ProfileEvent.SetupPaymentMethodClicked -> startPaymentMethodSetup()
            ProfileEvent.PaymentSheetLaunchHandled -> _uiState.update { it.copy(paymentSheetSetupData = null) }
            is ProfileEvent.PaymentSheetLaunchFailed -> handlePaymentSheetLaunchFailure(event.message)
            is ProfileEvent.PaymentSheetResultReceived -> handlePaymentSheetResult(event.result)
            
            ProfileEvent.AddTimeSlotClicked -> _uiState.update { it.copy(isAddTimeSlotDialogVisible = true) }
            ProfileEvent.AddTimeSlotDialogDismissed -> _uiState.update { it.copy(isAddTimeSlotDialogVisible = false) }
            is ProfileEvent.DayOfWeekSelected -> _uiState.update { it.copy(dialogSelectedDay = event.day) }
            is ProfileEvent.StartTimeSelected -> _uiState.update { it.copy(dialogStartTime = event.time) }
            is ProfileEvent.EndTimeSelected -> _uiState.update { it.copy(dialogEndTime = event.time) }
            ProfileEvent.AddTimeSlotConfirmed -> addAvailableTimeSlot()

            is ProfileEvent.DeleteTimeSlot -> deleteAvailableTimeSlot(event.timeSlotId)
        }
    }

    private fun loadProfileData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            val availableTimeSlotsResult = getUserAvailableTimeSlotsUseCase()
            val stripeAccountResult = getStripeAccountUseCase()

            availableTimeSlotsResult.exceptionOrNull()?.let { error ->
                Log.e(TAG, "Failed to load available time slots", error)
            }
            stripeAccountResult.exceptionOrNull()?.let { error ->
                Log.e(TAG, "Failed to load stripe account", error)
            }

            _uiState.update { current ->
                val sortedTimeSlots = availableTimeSlotsResult.getOrNull()
                    ?.sortedWith(
                        compareBy(RefereeAvailableTimeSlot::dow)
                            .thenBy(RefereeAvailableTimeSlot::startMin)
                    ) ?: current.availableTimeSlots

                val stripeAccount = if (stripeAccountResult.isSuccess) {
                    stripeAccountResult.getOrNull()
                } else {
                    current.stripeAccount
                }

                val errorMessage = availableTimeSlotsResult.exceptionOrNull()?.message
                    ?: stripeAccountResult.exceptionOrNull()?.message

                current.copy(
                    isLoading = false,
                    availableTimeSlots = sortedTimeSlots,
                    stripeAccount = stripeAccount,
                    error = errorMessage
                )
            }
        }
    }

    private fun addAvailableTimeSlot() {
        viewModelScope.launch {
            val currentState = _uiState.value
            val params = AddAvailableTimeSlotParams(
                dayOfWeek = currentState.dialogSelectedDay,
                startMin = currentState.dialogStartTime.hour * 60 + currentState.dialogStartTime.minute,
                endMin = currentState.dialogEndTime.hour * 60 + currentState.dialogEndTime.minute
            )

            addAvailableTimeSlotUseCase(params, currentState.availableTimeSlots)
                .onSuccess {
                    _uiState.update { it.copy(isAddTimeSlotDialogVisible = false) }
                    loadProfileData()
                }
                .onFailure { error -> 
                    Log.e(TAG, "Failed to add available time slot", error)
                    _uiState.update { it.copy(error = error.message) } 
                }
        }
    }

    private fun deleteAvailableTimeSlot(timeSlotId: String) {
        viewModelScope.launch {
            deleteAvailableTimeSlotUseCase(timeSlotId)
                .onSuccess { loadProfileData() }
                .onFailure { error -> 
                    Log.e(TAG, "Failed to delete available time slot with id: $timeSlotId", error)
                    _uiState.update { it.copy(error = error.message) } 
                }
        }
    }

    private fun startPaymentMethodSetup() {
        if (_uiState.value.isPaymentSheetInProgress) return
        viewModelScope.launch {
            _uiState.update {
                it.copy(
                    isPaymentSheetInProgress = true,
                    paymentSheetError = null,
                    paymentSheetMessage = null,
                    paymentSheetSetupData = null
                )
            }

            createStripePaymentSetupSessionUseCase()
                .onSuccess { session ->
                    _uiState.update { it.copy(paymentSheetSetupData = session) }
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to create billing setup session", error)
                    _uiState.update {
                        it.copy(
                            isPaymentSheetInProgress = false,
                            paymentSheetError = error.message ?: "Failed to start payment setup"
                        )
                    }
                }
        }
    }

    private fun handlePaymentSheetLaunchFailure(message: String) {
        _uiState.update {
            it.copy(
                isPaymentSheetInProgress = false,
                paymentSheetSetupData = null,
                paymentSheetError = message
            )
        }
    }

    private fun handlePaymentSheetResult(result: PaymentSheetResult) {
        when (result) {
            PaymentSheetResult.Completed -> {
                _uiState.update {
                    it.copy(
                        isPaymentSheetInProgress = false,
                        paymentSheetMessage = "Payment method successfully registered",
                        paymentSheetError = null
                    )
                }
                refreshStripeAccount()
            }
            PaymentSheetResult.Canceled -> {
                _uiState.update {
                    it.copy(
                        isPaymentSheetInProgress = false,
                        paymentSheetMessage = "Payment method setup canceled",
                        paymentSheetError = null
                    )
                }
            }
            is PaymentSheetResult.Failed -> {
                Log.e(TAG, "PaymentSheet failed", result.error)
                _uiState.update {
                    it.copy(
                        isPaymentSheetInProgress = false,
                        paymentSheetError = result.error.message ?: "Payment method setup failed"
                    )
                }
            }
        }
    }

    private fun refreshStripeAccount() {
        viewModelScope.launch {
            getStripeAccountUseCase()
                .onSuccess { account ->
                    _uiState.update { it.copy(stripeAccount = account) }
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to refresh stripe account", error)
                }
        }
    }

    private fun createConnectLink() {
        viewModelScope.launch {
            _uiState.update { it.copy(connectLinkState = ConnectLinkState.Loading) }
            createStripeConnectLinkUseCase()
                .onSuccess { url -> _uiState.update { it.copy(connectLinkState = ConnectLinkState.Success(url)) } }
                .onFailure { error -> 
                    Log.e(TAG, "Failed to create Stripe Connect link", error)
                    _uiState.update { it.copy(connectLinkState = ConnectLinkState.Error(error.message ?: "Unknown error")) } 
                }
        }
    }
}
