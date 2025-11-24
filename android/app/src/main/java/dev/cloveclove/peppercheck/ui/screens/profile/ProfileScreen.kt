package dev.cloveclove.peppercheck.ui.screens.profile

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import dev.cloveclove.peppercheck.navigation.Screen
import dev.cloveclove.peppercheck.ui.components.common.AppScaffold
import dev.cloveclove.peppercheck.ui.components.profile.AddAvailableTimeSlotDialog
import dev.cloveclove.peppercheck.ui.components.profile.ConnectAccountSection
import dev.cloveclove.peppercheck.ui.components.profile.RefereeAvailableTimeSlotSection
import dev.cloveclove.peppercheck.ui.components.profile.StripePaymentMethodSection
import dev.cloveclove.peppercheck.ui.components.profile.PayoutRequestSection
import dev.cloveclove.peppercheck.ui.components.profile.PayoutAmountDialog
import dev.cloveclove.peppercheck.ui.theme.TextBlack
import dev.cloveclove.peppercheck.ui.theme.standardScreenPadding
import com.stripe.android.paymentsheet.PaymentSheet
import com.stripe.android.paymentsheet.rememberPaymentSheet

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    navController: NavController,
    viewModel: ProfileViewModel
) {
    val uiState by viewModel.uiState.collectAsState()
    val pullToRefreshState = rememberPullToRefreshState()
    val context = LocalContext.current

    val paymentSheet = rememberPaymentSheet { result ->
        viewModel.onEvent(ProfileEvent.PaymentSheetResultReceived(result))
    }

    LaunchedEffect(uiState.connectLinkState) {
        if (uiState.connectLinkState is ConnectLinkState.Success) {
            val url = (uiState.connectLinkState as ConnectLinkState.Success).url
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            context.startActivity(intent)
            viewModel.onEvent(ProfileEvent.ConnectLinkHandled)
        }
    }

    LaunchedEffect(uiState.paymentSheetSetupData) {
        val setupData = uiState.paymentSheetSetupData ?: return@LaunchedEffect
        val hasRequiredSecrets = setupData.setupIntentClientSecret.isNotBlank() &&
            setupData.ephemeralKeySecret.isNotBlank()

        val presentationResult = if (hasRequiredSecrets) {
            runCatching {
                paymentSheet.presentWithSetupIntent(
                    setupData.setupIntentClientSecret,
                    PaymentSheet.Configuration(
                        merchantDisplayName = "Peppercheck",
                        customer = PaymentSheet.CustomerConfiguration(
                            setupData.customerId,
                            setupData.ephemeralKeySecret
                        )
                    )
                )
            }
        } else {
            Result.failure(IllegalStateException("Missing Stripe secrets for PaymentSheet"))
        }

        presentationResult.exceptionOrNull()?.let { error ->
            viewModel.onEvent(
                ProfileEvent.PaymentSheetLaunchFailed(
                    error.message ?: "Failed to open payment sheet"
                )
            )
        }

        viewModel.onEvent(ProfileEvent.PaymentSheetLaunchHandled)
    }

    AppScaffold(
        navController = navController,
        currentScreenRoute = Screen.Profile.route
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = uiState.isLoading,
            onRefresh = { viewModel.onEvent(ProfileEvent.RefreshData) },
            state = pullToRefreshState,
            modifier = Modifier.fillMaxSize().padding(padding)
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize().standardScreenPadding(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item {
                    Text(
                        "Profile",
                        style = MaterialTheme.typography.titleLarge.copy(
                            color = TextBlack,
                            fontWeight = FontWeight.Bold
                        )
                    )
                }
                item {
                    RefereeAvailableTimeSlotSection(
                        timeSlots = uiState.availableTimeSlots,
                        isLoading = uiState.isLoading,
                        error = uiState.error,
                        onAddClick = { viewModel.onEvent(ProfileEvent.AddTimeSlotClicked) },
                        onDeleteClick = { id -> viewModel.onEvent(ProfileEvent.DeleteTimeSlot(id)) }
                    )
                }
                item {
                    StripePaymentMethodSection(
                        stripeAccount = uiState.stripeAccount,
                        isSetupInProgress = uiState.isPaymentSheetInProgress,
                        statusMessage = uiState.paymentSheetMessage,
                        errorMessage = uiState.paymentSheetError,
                        onRegisterPaymentMethodClick = { viewModel.onEvent(ProfileEvent.SetupPaymentMethodClicked) }
                    )
                }
                item {
                    ConnectAccountSection(
                        stripeAccount = uiState.stripeAccount,
                        connectLinkState = uiState.connectLinkState,
                        onSetupClick = { viewModel.onEvent(ProfileEvent.CreateConnectLink) }
                    )
                }
                item {
                    PayoutRequestSection(
                        availableMinor = uiState.payoutAvailableMinor,
                        pendingMinor = uiState.payoutPendingMinor,
                        incomingPendingMinor = uiState.payoutIncomingPendingMinor,
                        currencyCode = uiState.payoutCurrency,
                        payoutsEnabled = uiState.stripeAccount?.payoutsEnabled == true,
                        isInProgress = uiState.isPayoutInProgress,
                        message = uiState.payoutMessage,
                        error = uiState.payoutError,
                        onRequestClick = { viewModel.onEvent(ProfileEvent.PayoutRequestClicked) }
                    )
                }
            }
        }
    }

    if (uiState.isAddTimeSlotDialogVisible) {
        AddAvailableTimeSlotDialog(
            selectedDay = uiState.dialogSelectedDay,
            startTime = uiState.dialogStartTime,
            endTime = uiState.dialogEndTime,
            onDismiss = { viewModel.onEvent(ProfileEvent.AddTimeSlotDialogDismissed) },
            onDaySelected = { day -> viewModel.onEvent(ProfileEvent.DayOfWeekSelected(day)) },
            onStartTimeSelected = { time -> viewModel.onEvent(ProfileEvent.StartTimeSelected(time))},
            onEndTimeSelected = { time -> viewModel.onEvent(ProfileEvent.EndTimeSelected(time)) },
            onConfirm = { viewModel.onEvent(ProfileEvent.AddTimeSlotConfirmed) }
        )
    }

    if (uiState.isPayoutDialogVisible) {
        PayoutAmountDialog(
            amountMinor = uiState.payoutInputMinor,
            currencyCode = uiState.payoutCurrency,
            isSubmitting = uiState.isPayoutInProgress,
            onAmountChange = { amount -> viewModel.onEvent(ProfileEvent.PayoutAmountChanged(amount)) },
            onConfirm = { viewModel.onEvent(ProfileEvent.ConfirmPayout) },
            onDismiss = { viewModel.onEvent(ProfileEvent.PayoutDialogDismissed) }
        )
    }
}
