package dev.cloveclove.peppercheck.ui.screens.task.tasker

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import dev.cloveclove.peppercheck.ui.components.common.AppScaffold
import dev.cloveclove.peppercheck.ui.components.common.CancelButton
import dev.cloveclove.peppercheck.ui.components.common.DateTimePickerDialogs
import dev.cloveclove.peppercheck.ui.components.common.PrimaryActionButton
import dev.cloveclove.peppercheck.ui.components.evidence.SubmitEvidenceSection
import dev.cloveclove.peppercheck.ui.components.evidence.SubmittedEvidenceSection
import dev.cloveclove.peppercheck.ui.components.judgement.JudgementResultsSection
import dev.cloveclove.peppercheck.ui.components.rating.RatingDialog
import dev.cloveclove.peppercheck.ui.components.task.MatchingStrategySelectionSection
import dev.cloveclove.peppercheck.ui.components.task.TaskFormSection
import dev.cloveclove.peppercheck.ui.components.task.TaskInformationSection
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.TextBlack
import dev.cloveclove.peppercheck.ui.theme.standardScreenPadding

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaskerScreen(
    uiState: TaskerUiState,
    onEvent: (TaskerEvent) -> Unit,
    navController: NavController
) {
    // イメージピッカーランチャーをScreenレベルで定義
    val imagePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetMultipleContents(),
        onResult = { uris -> 
            if (uris.isNotEmpty()) {
                onEvent(TaskerEvent.ImagesSelected(uris))
            }
        }
    )

    AppScaffold(
        navController = navController,
        currentScreenRoute = "" 
    ) { paddingValues ->
        val pullToRefreshState = rememberPullToRefreshState()

        PullToRefreshBox(
            isRefreshing = uiState.isLoading,
            onRefresh = { onEvent(TaskerEvent.RefreshTask) },
            state = pullToRefreshState,
            modifier = Modifier.fillMaxSize().padding(paddingValues)
        ) {
            when {
                uiState.isLoading && uiState.task == null -> LoadingContent()
                uiState.error != null -> ErrorContent(
                    error = uiState.error,
                    onRetry = { onEvent(TaskerEvent.RefreshTask) }
                )
                uiState.task != null -> {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxSize()
                            .standardScreenPadding()
                    ) {
                        item {
                            Text(
                                text = "Your task",
                                style = MaterialTheme.typography.titleLarge.copy(
                                    color = TextBlack,
                                    fontWeight = FontWeight.Bold
                                )
                            )
                        }
                        item { Spacer(modifier = Modifier.height(12.dp)) }

                        item {
                            if (uiState.isEditingTask) {
                                TaskFormSection(
                                    title = uiState.editTaskForm.title,
                                    onTitleChange = { onEvent(TaskerEvent.TitleChanged(it)) },
                                    description = uiState.editTaskForm.description,
                                    onDescriptionChange = { onEvent(TaskerEvent.DescriptionChanged(it)) },
                                    criteria = uiState.editTaskForm.criteria,
                                    onCriteriaChange = { onEvent(TaskerEvent.CriteriaChanged(it)) },
                                    selectedDateTime = uiState.editTaskForm.selectedDateTime,
                                    onDateTimeClick = { onEvent(TaskerEvent.DateTimeClicked) },
                                    taskStatus = uiState.editTaskForm.taskStatus,
                                    onStatusChange = { onEvent(TaskerEvent.StatusChanged(it)) }
                                )
                            } else {
                                TaskInformationSection(
                                    task = uiState.task,
                                    onEditClick = { onEvent(TaskerEvent.EditTaskClicked) }
                                )
                            }
                        }

                        // 編集モードかつステータスが "open" の場合にMatchingStrategySelectionSectionを表示
                        if (uiState.isEditingTask && uiState.editTaskForm.taskStatus == "open") {
                            item { Spacer(modifier = Modifier.height(8.dp)) }
                            item {
                                MatchingStrategySelectionSection(
                                    selectedStrategies = uiState.editTaskForm.selectedStrategies,
                                    onStrategiesChange = { onEvent(TaskerEvent.StrategiesChanged(it)) }
                                )
                            }
                        }

                        // 編集モードの場合に保存・キャンセルボタンを表示
                        if (uiState.isEditingTask) {
                            item { Spacer(modifier = Modifier.height(12.dp)) }
                            item {
                                Column(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    PrimaryActionButton(
                                        text = "Save",
                                        onClick = { onEvent(TaskerEvent.SaveTaskClicked) },
                                        enabled = uiState.editTaskForm.isFormValid,
                                        isLoading = uiState.isLoading
                                    )
                                    CancelButton(
                                        onClick = { onEvent(TaskerEvent.CancelEditTaskClicked) }
                                    )
                                }
                            }
                        }

                        if (uiState.task.status != "draft") {
                            item { Spacer(modifier = Modifier.height(12.dp)) }
                            item {
                                if (uiState.evidence != null && !uiState.isEditingEvidence) {
                                    SubmittedEvidenceSection(
                                        evidence = uiState.evidence,
                                        onEditEvidence = { onEvent(TaskerEvent.EditEvidenceClicked) }
                                    )
                                } else {
                                    val isDueDatePassed = remember(uiState.task.dueDate) {
                                        uiState.task.dueDate?.let { dueDate ->
                                            try {
                                                val dueDateInstant = java.time.Instant.parse(dueDate)
                                                val now = java.time.Instant.now()
                                                !dueDateInstant.isAfter(now)
                                            } catch (e: Exception) {
                                                false
                                            }
                                        } ?: false
                                    }
                                    
                                    SubmitEvidenceSection(
                                        description = uiState.evidenceForm.description,
                                        onDescriptionChange = { onEvent(TaskerEvent.EvidenceDescriptionChanged(it)) },
                                        initialImageUrls = uiState.evidenceForm.initialImageUrls,
                                        newImageUris = uiState.evidenceForm.newlyAddedImageUris,
                                        onAddImagesClick = { imagePickerLauncher.launch("image/*") },
                                        onRemoveInitialImage = { onEvent(TaskerEvent.InitialImageRemoved(it)) },
                                        onRemoveNewImage = { onEvent(TaskerEvent.NewImageUriRemoved(it)) },
                                        isSubmitEnabled = uiState.evidenceForm.isSubmitEnabled,
                                        isDueDatePassed = isDueDatePassed,
                                        onSubmitClick = { onEvent(TaskerEvent.SubmitEvidenceClicked) }
                                    )
                                }
                            }
                        }

                        if (uiState.judgements.isNotEmpty()) {
                            item { Spacer(modifier = Modifier.height(12.dp)) }
                            item {
                                JudgementResultsSection(
                                    judgements = uiState.judgements,
                                    onConfirmJudgementClick = { onEvent(TaskerEvent.ConfirmJudgementClicked(it)) },
                                    onReopenJudgementClick = { onEvent(TaskerEvent.ReopenJudgementClicked(it)) },
                                    showEvaluationMessage = uiState.areAllJudgementsApproved && !uiState.canBeClosed,
                                    taskDueDate = uiState.task.dueDate
                                )
                            }
                        }

                        // タスク完了状態の表示
                        if (uiState.areAllJudgementsApproved) {
                            item { Spacer(modifier = Modifier.height(12.dp)) }
                            item {
                                if (uiState.task.status == "closed") {
                                    Text(
                                        text = "This task is closed",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = TextBlack.copy(alpha = 0.6f),
                                        modifier = Modifier.fillMaxWidth(),
                                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                                    )
                                } else if (uiState.canBeClosed) {
                                    PrimaryActionButton(
                                        text = "Complete Task",
                                        onClick = { onEvent(TaskerEvent.CloseTaskClicked) },
                                        enabled = !uiState.isLoading
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 旧実装のRating Dialog
    if (uiState.ratingDialogState.isVisible) {
        RatingDialog(
            targetUserName = uiState.ratingDialogState.targetJudgement?.refereeName ?: "Referee",
            rating = uiState.ratingDialogState.rating,
            comment = uiState.ratingDialogState.comment,
            isSubmitEnabled = uiState.ratingDialogState.isSubmitEnabled,
            onRatingChanged = { onEvent(TaskerEvent.RatingChanged(it)) },
            onCommentChanged = { onEvent(TaskerEvent.RatingCommentChanged(it)) },
            onRatingSubmit = { onEvent(TaskerEvent.SubmitRatingClicked) },
            onDismiss = { onEvent(TaskerEvent.RatingDialogDismissed) }
        )
    }
    
    // 新実装のConfirmJudgement Dialog
    if (uiState.confirmJudgementDialogState.isVisible) {
        RatingDialog(
            targetUserName = uiState.confirmJudgementDialogState.targetJudgement?.refereeName ?: "Referee",
            rating = uiState.confirmJudgementDialogState.rating,
            comment = uiState.confirmJudgementDialogState.comment,
            isSubmitEnabled = uiState.confirmJudgementDialogState.isSubmitEnabled,
            onRatingChanged = { onEvent(TaskerEvent.ConfirmJudgementRatingChanged(it)) },
            onCommentChanged = { onEvent(TaskerEvent.ConfirmJudgementCommentChanged(it)) },
            onRatingSubmit = { onEvent(TaskerEvent.SubmitJudgementConfirmationClicked) },
            onDismiss = { onEvent(TaskerEvent.ConfirmJudgementDialogDismissed) }
        )
    }

    DateTimePickerDialogs(
        showDatePicker = uiState.isDatePickerVisible,
        showTimePicker = uiState.isTimePickerVisible,
        onDatePickerDismiss = { onEvent(TaskerEvent.DatePickerDismissed) },
        onTimePickerDismiss = { onEvent(TaskerEvent.TimePickerDismissed) },
        onDateSelected = { onEvent(TaskerEvent.DateSelected) },
        onDateTimeSelected = { onEvent(TaskerEvent.TimeSelected(it)) }
    )
}

@Composable
private fun LoadingContent() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(color = AccentYellow)
    }
}

@Composable
private fun ErrorContent(
    error: String,
    onRetry: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("Error occurred", style = MaterialTheme.typography.headlineSmall)
        Spacer(modifier = Modifier.height(8.dp))
        Text(error, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = onRetry) {
            Text("Retry")
        }
    }
}
