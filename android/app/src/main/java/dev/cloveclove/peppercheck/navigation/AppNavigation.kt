package dev.cloveclove.peppercheck.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import dev.cloveclove.peppercheck.di.ViewModelFactory
import dev.cloveclove.peppercheck.ui.screens.create_task.CreateTaskScreen
import dev.cloveclove.peppercheck.ui.screens.create_task.CreateTaskViewModel
import dev.cloveclove.peppercheck.ui.screens.home.HomeScreen
import dev.cloveclove.peppercheck.ui.screens.home.HomeViewModel
import dev.cloveclove.peppercheck.ui.screens.login.LoginScreen
import dev.cloveclove.peppercheck.ui.screens.login.LoginViewModel
import dev.cloveclove.peppercheck.ui.screens.profile.ProfileScreen
import dev.cloveclove.peppercheck.ui.screens.profile.ProfileViewModel
import dev.cloveclove.peppercheck.ui.screens.task.referee.RefereeEvent
import dev.cloveclove.peppercheck.ui.screens.task.referee.RefereeScreen
import dev.cloveclove.peppercheck.ui.screens.task.referee.RefereeViewModel
import dev.cloveclove.peppercheck.ui.screens.task.tasker.TaskerEvent
import dev.cloveclove.peppercheck.ui.screens.task.tasker.TaskerScreen
import dev.cloveclove.peppercheck.ui.screens.task.tasker.TaskerViewModel

sealed class Screen(val route: String) {
    object Login : Screen("login")
    object Home : Screen("home")
    object CreateTask : Screen("create_task")
    object Profile : Screen("profile")
    object TaskerTask : Screen("tasker_task/{taskId}") {
        fun createRoute(taskId: String) = "tasker_task/$taskId"
    }
    object RefereeTask : Screen("referee_task/{taskId}") {
        fun createRoute(taskId: String) = "referee_task/$taskId"
    }
}

@Composable
fun AppNavHost(
    navController: NavHostController,
    startDestination: String,
    modifier: Modifier = Modifier,
    factory: ViewModelFactory // ViewModelFactoryを受け取る
) {
    NavHost(
        navController = navController, 
        startDestination = startDestination,
        modifier = modifier
    ) {
        composable(Screen.Login.route) {
            val loginViewModel: LoginViewModel = viewModel(factory = factory)
            LoginScreen(navController, loginViewModel)
        }
        composable(Screen.Home.route) {
            val homeViewModel: HomeViewModel = viewModel(factory = factory)
            HomeScreen(navController, homeViewModel)
        }
        composable(Screen.CreateTask.route) {
            val createTaskViewModel: CreateTaskViewModel = viewModel(factory = factory)
            CreateTaskScreen(navController, createTaskViewModel)
        }
        composable(Screen.Profile.route) {
            val profileViewModel: ProfileViewModel = viewModel(factory = factory)
            ProfileScreen(navController, profileViewModel)
        }
        composable(
            route = Screen.TaskerTask.route,
            arguments = listOf(navArgument("taskId") { type = NavType.StringType })
        ) { backStackEntry ->
            val taskId = backStackEntry.arguments?.getString("taskId") ?: ""
            val taskerViewModel: TaskerViewModel = viewModel(factory = factory)
            
            val uiState by taskerViewModel.uiState.collectAsState()
            LaunchedEffect(taskId) {
                taskerViewModel.onEvent(TaskerEvent.LoadTask(taskId))
            }
            TaskerScreen(
                uiState = uiState,
                onEvent = taskerViewModel::onEvent,
                navController = navController
            )
        }

        composable(
            route = Screen.RefereeTask.route,
            arguments = listOf(navArgument("taskId") { type = NavType.StringType })
        ) { backStackEntry ->
            val taskId = backStackEntry.arguments?.getString("taskId") ?: ""
            val refereeViewModel: RefereeViewModel = viewModel(factory = factory)

            val uiState by refereeViewModel.uiState.collectAsState()
            LaunchedEffect(taskId) {
                refereeViewModel.onEvent(RefereeEvent.LoadTask(taskId))
            }
            RefereeScreen(
                uiState = uiState,
                onEvent = refereeViewModel::onEvent,
                navController = navController
            )
        }
    }
}
