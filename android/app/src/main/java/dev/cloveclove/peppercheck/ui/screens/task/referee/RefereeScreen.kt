package dev.cloveclove.peppercheck.ui.screens.task.referee

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import dev.cloveclove.peppercheck.ui.components.common.AppScaffold
import dev.cloveclove.peppercheck.ui.components.evidence.SubmittedEvidenceSection
import dev.cloveclove.peppercheck.ui.components.judgement.EvidenceTimeoutSection
import dev.cloveclove.peppercheck.ui.components.judgement.SubmitJudgementSection
import dev.cloveclove.peppercheck.ui.components.judgement.SubmittedJudgementSection
import dev.cloveclove.peppercheck.ui.components.task.TaskInformationSection
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.TextBlack
import dev.cloveclove.peppercheck.ui.theme.standardScreenPadding

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RefereeScreen(
    uiState: RefereeUiState,
    onEvent: (RefereeEvent) -> Unit,
    navController: NavController
) {
    // AppScaffoldで共通レイアウトを適用
    AppScaffold(
        navController = navController,
        currentScreenRoute = "" // 詳細画面なのでタブは選択状態にしない
    ) { paddingValues ->
        val pullToRefreshState = rememberPullToRefreshState()

        PullToRefreshBox(
            isRefreshing = uiState.isLoading,
            onRefresh = { onEvent(RefereeEvent.RefreshTask) },
            state = pullToRefreshState,
            modifier = Modifier.fillMaxSize().padding(paddingValues)
        ) {
            // UiStateの状態に応じてUIを切り替える
            when {
                uiState.isLoading && uiState.task == null -> LoadingContent()
                uiState.error != null -> ErrorContent(
                    error = uiState.error,
                    onRetry = { onEvent(RefereeEvent.RefreshTask) }
                )
                uiState.task != null -> {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxSize()
                            .standardScreenPadding(),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        // 画面のタイトルを追加
                        item {
                            Text(
                                text = "Referee Task",
                                style = MaterialTheme.typography.titleLarge.copy(
                                    color = TextBlack,
                                    fontWeight = FontWeight.Bold
                                )
                            )
                        }

                        item {
                            TaskInformationSection(task = uiState.task) // Refereeはタスクを編集できない
                        }

                        item {
                            SubmittedEvidenceSection(evidence = uiState.evidence)
                        }

                        // Judgement section - show based on judgement status
                        uiState.myJudgement?.let { judgement ->
                            item {
                                when {
                                    // Evidence timeout case - show confirm button if not confirmed yet
                                    judgement.status == "evidence_timeout" && !judgement.isEvidenceTimeoutConfirmed -> {
                                        EvidenceTimeoutSection(
                                            onConfirmClick = { onEvent(RefereeEvent.ConfirmEvidenceTimeoutClicked) },
                                            isConfirmEnabled = !uiState.isLoading
                                        )
                                    }
                                    // Evidence timeout confirmed - show as submitted judgement without edit button
                                    judgement.status == "evidence_timeout" && judgement.isEvidenceTimeoutConfirmed -> {
                                        SubmittedJudgementSection(
                                            judgement = judgement.copy(
                                                status = "Evidence Timeout Confirmed",
                                                comment = "Evidence was not submitted by the due date. Confirmed by referee."
                                            ),
                                            onEditClick = null // No edit button for evidence timeout confirmed
                                        )
                                    }
                                    // Already submitted judgement and not editing
                                    judgement.status in listOf("approved", "rejected") && !uiState.isEditingJudgement -> {
                                        SubmittedJudgementSection(
                                            judgement = judgement,
                                            onEditClick = { onEvent(RefereeEvent.EditJudgementClicked) }
                                        )
                                    }
                                    // Normal case - show submit judgement form (only if evidence exists)
                                    uiState.evidence != null -> {
                                        SubmitJudgementSection(
                                            comment = uiState.judgementForm.comment,
                                            onCommentChange = { onEvent(RefereeEvent.JudgementCommentChanged(it)) },
                                            selectedStatus = uiState.judgementForm.status,
                                            onStatusSelected = { onEvent(RefereeEvent.JudgementStatusSelected(it)) },
                                            isSubmitEnabled = uiState.judgementForm.isSubmitEnabled,
                                            onSubmitClick = { onEvent(RefereeEvent.SubmitJudgementClicked) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
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