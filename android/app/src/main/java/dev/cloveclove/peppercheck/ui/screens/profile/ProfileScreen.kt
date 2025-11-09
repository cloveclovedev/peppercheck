package dev.cloveclove.peppercheck.ui.screens.profile

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.*
import androidx.compose.runtime.*
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
import dev.cloveclove.peppercheck.ui.theme.TextBlack
import dev.cloveclove.peppercheck.ui.theme.standardScreenPadding

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    navController: NavController,
    viewModel: ProfileViewModel
) {
    val uiState by viewModel.uiState.collectAsState()
    val pullToRefreshState = rememberPullToRefreshState()
    val context = LocalContext.current

    LaunchedEffect(uiState.connectLinkState) {
        if (uiState.connectLinkState is ConnectLinkState.Success) {
            val url = (uiState.connectLinkState as ConnectLinkState.Success).url
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            context.startActivity(intent)
            viewModel.onEvent(ProfileEvent.ConnectLinkHandled)
        }
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
                        isLoading = uiState.isLoading,
                        onRegisterPaymentMethodClick = { viewModel.onEvent(ProfileEvent.SetupPaymentMethodClicked) }
                    )
                }
                item {
                    ConnectAccountSection(
                        connectLinkState = uiState.connectLinkState,
                        onSetupClick = { viewModel.onEvent(ProfileEvent.CreateConnectLink) }
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
}
