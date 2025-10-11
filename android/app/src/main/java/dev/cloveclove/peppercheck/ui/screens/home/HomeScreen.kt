package dev.cloveclove.peppercheck.ui.screens.home

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import dev.cloveclove.peppercheck.navigation.Screen
import dev.cloveclove.peppercheck.ui.components.common.AppScaffold
import dev.cloveclove.peppercheck.ui.components.task.TaskCardsSection
import dev.cloveclove.peppercheck.ui.theme.TextBlack
import dev.cloveclove.peppercheck.ui.theme.standardScreenPadding

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    navController: NavController,
    viewModel: HomeViewModel
) {
    val uiState by viewModel.uiState.collectAsState()
    val pullToRefreshState = rememberPullToRefreshState()

    AppScaffold(
        navController = navController,
        currentScreenRoute = Screen.Home.route
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = uiState.isLoading,
            onRefresh = { viewModel.onEvent(HomeScreenEvent.RefreshTasks) },
            state = pullToRefreshState,
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .standardScreenPadding()
            ) {
                item {
                    Text(
                        "Home",
                        style = MaterialTheme.typography.titleLarge.copy(
                            color = TextBlack,
                            fontWeight = FontWeight.Bold
                        )
                    )
                }
                item { Spacer(modifier = Modifier.height(12.dp)) }
                item {
                    TaskCardsSection(
                        title = "Your tasks",
                        tasks = uiState.yourTasks,
                        onTaskClick = { task ->
                            navController.navigate(Screen.TaskerTask.createRoute(task.id))
                        }
                    )
                }
                item { Spacer(modifier = Modifier.height(12.dp)) }
                item {
                    TaskCardsSection(
                        title = "Referee tasks",
                        tasks = uiState.refereeTasks,
                        onTaskClick = { task ->
                            navController.navigate(Screen.RefereeTask.createRoute(task.id))
                        }
                    )
                }
                uiState.errorMessage?.let { error ->
                    item {
                        Text(
                            text = "Error: $error",
                            color = MaterialTheme.colorScheme.error,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(top = 8.dp)
                        )
                    }
                }
            }
        }
    }
}

