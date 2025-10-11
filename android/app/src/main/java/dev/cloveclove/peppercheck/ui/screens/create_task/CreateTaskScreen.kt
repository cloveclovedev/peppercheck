package dev.cloveclove.peppercheck.ui.screens.create_task

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import dev.cloveclove.peppercheck.navigation.Screen
import dev.cloveclove.peppercheck.ui.components.common.AppScaffold
import dev.cloveclove.peppercheck.ui.components.common.DateTimePickerDialogs
import dev.cloveclove.peppercheck.ui.components.common.PrimaryActionButton
import dev.cloveclove.peppercheck.ui.components.task.MatchingStrategySelectionSection
import dev.cloveclove.peppercheck.ui.components.task.TaskFormSection
import dev.cloveclove.peppercheck.ui.theme.TextBlack
import dev.cloveclove.peppercheck.ui.theme.standardScreenPadding

@Composable
fun CreateTaskScreen(
    navController: NavController,
    viewModel: CreateTaskViewModel
) {
    val uiState by viewModel.uiState.collectAsState()

    // 成功したら前の画面に戻る
    LaunchedEffect(uiState.isSuccess) {
        if (uiState.isSuccess) {
            navController.popBackStack()
            // isSuccessの状態をリセットするイベントを発行
            viewModel.onEvent(CreateTaskEvent.SuccessMessageConsumed)
        }
    }

    AppScaffold(
        navController = navController,
        currentScreenRoute = Screen.CreateTask.route
    ) { paddingValues ->
        Box(
            modifier = Modifier.padding(paddingValues)
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .standardScreenPadding()
            ) {
                item {
                    Text(
                        "Create Task",
                        style = MaterialTheme.typography.titleLarge.copy(
                            color = TextBlack,
                            fontWeight = FontWeight.Bold
                        )
                    )
                }
                item { Spacer(modifier = Modifier.height(12.dp)) }
                item {
                    TaskFormSection(
                        title = uiState.title,
                        onTitleChange = { viewModel.onEvent(CreateTaskEvent.TitleChanged(it)) },
                        description = uiState.description,
                        onDescriptionChange = {
                            viewModel.onEvent(
                                CreateTaskEvent.DescriptionChanged(
                                    it
                                )
                            )
                        },
                        criteria = uiState.criteria,
                        onCriteriaChange = { viewModel.onEvent(CreateTaskEvent.CriteriaChanged(it)) },
                        selectedDateTime = uiState.selectedDateTime,
                        onDateTimeClick = { viewModel.onEvent(CreateTaskEvent.DateTimeClicked) },
                        taskStatus = uiState.taskStatus,
                        onStatusChange = { viewModel.onEvent(CreateTaskEvent.StatusChanged(it)) }
                    )
                }
                if (uiState.taskStatus == "open") {
                    item { Spacer(modifier = Modifier.height(8.dp)) }
                    item {
                        MatchingStrategySelectionSection(
                            selectedStrategies = uiState.selectedStrategies,
                            onStrategiesChange = {
                                viewModel.onEvent(
                                    CreateTaskEvent.StrategiesChanged(
                                        it
                                    )
                                )
                            }
                        )
                    }
                }
                item { Spacer(modifier = Modifier.height(12.dp)) }
                uiState.error?.let { message ->
                    item {
                        Text(
                            text = "Error: $message",
                            color = MaterialTheme.colorScheme.error,
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                    item { Spacer(modifier = Modifier.height(4.dp)) }
                }
                item {
                    PrimaryActionButton(
                        text = "Create",
                        onClick = { viewModel.onEvent(CreateTaskEvent.CreateTaskClicked) },
                        enabled = uiState.isFormValid,
                        isLoading = uiState.isLoading
                    )
                }
            }
        }
    }

    DateTimePickerDialogs(
        showDatePicker = uiState.isDatePickerVisible,
        showTimePicker = uiState.isTimePickerVisible,
        onDatePickerDismiss = { viewModel.onEvent(CreateTaskEvent.DatePickerDismissed) },
        onTimePickerDismiss = { viewModel.onEvent(CreateTaskEvent.TimePickerDismissed) },
        onDateSelected = { viewModel.onEvent(CreateTaskEvent.DateSelected) },
        onDateTimeSelected = { viewModel.onEvent(CreateTaskEvent.TimeSelected(it)) }
    )
}
