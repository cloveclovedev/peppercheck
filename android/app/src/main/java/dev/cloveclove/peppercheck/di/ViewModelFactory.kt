package dev.cloveclove.peppercheck.di

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import dev.cloveclove.peppercheck.ui.screens.create_task.CreateTaskViewModel
import dev.cloveclove.peppercheck.ui.screens.home.HomeViewModel
import dev.cloveclove.peppercheck.ui.screens.login.LoginViewModel
import dev.cloveclove.peppercheck.ui.screens.profile.ProfileViewModel
import dev.cloveclove.peppercheck.ui.screens.task.referee.RefereeViewModel
import dev.cloveclove.peppercheck.ui.screens.task.tasker.TaskerViewModel
import java.lang.IllegalArgumentException

/**
 * ViewModelに依存関係を注入するためのFactoryクラス。
 * AppContainerを受け取り、適切なRepositoryを各ViewModelに渡します。
 */
class ViewModelFactory(private val container: AppContainer) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return when {
            modelClass.isAssignableFrom(LoginViewModel::class.java) -> {
                LoginViewModel(container.authRepository) as T
            }
            modelClass.isAssignableFrom(HomeViewModel::class.java) -> {
                HomeViewModel(container.getHomeTasksUseCase) as T
            }
            modelClass.isAssignableFrom(CreateTaskViewModel::class.java) -> {
                CreateTaskViewModel(container.createTaskUseCase) as T
            }
            modelClass.isAssignableFrom(ProfileViewModel::class.java) -> {
                ProfileViewModel(
                    getUserAvailableTimeSlotsUseCase = container.getUserAvailableTimeSlotsUseCase,
                    addAvailableTimeSlotUseCase = container.addAvailableTimeSlotUseCase,
                    deleteAvailableTimeSlotUseCase = container.deleteAvailableTimeSlotUseCase,
                    createStripeConnectLinkUseCase = container.createStripeConnectLinkUseCase,
                    getStripeAccountUseCase = container.getStripeAccountUseCase,
                    createStripePaymentSetupSessionUseCase = container.createStripePaymentSetupSessionUseCase
                ) as T
            }
            modelClass.isAssignableFrom(TaskerViewModel::class.java) -> {
                TaskerViewModel(
                    getTaskDetailsUseCase = container.getTaskDetailsUseCase,
                    updateTaskUseCase = container.updateTaskUseCase,
                    submitEvidenceUseCase = container.submitEvidenceUseCase,
                    submitRefereeRatingUseCase = container.submitRefereeRatingUseCase,
                    confirmJudgementUseCase = container.confirmJudgementUseCase,
                    confirmRefereeTimeoutJudgementUseCase = container.confirmRefereeTimeoutJudgementUseCase,
                    closeTaskUseCase = container.closeTaskUseCase,
                    reopenJudgementUseCase = container.reopenJudgementUseCase
                ) as T
            }
            modelClass.isAssignableFrom(RefereeViewModel::class.java) -> {
                RefereeViewModel(
                    getTaskDetailsUseCase = container.getTaskDetailsUseCase,
                    updateJudgementUseCase = container.updateJudgementUseCase,
                    confirmEvidenceTimeoutFromRefereeUseCase = container.confirmEvidenceTimeoutFromRefereeUseCase
                ) as T
            }
            else -> {
                throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
            }
        }
    }
}
