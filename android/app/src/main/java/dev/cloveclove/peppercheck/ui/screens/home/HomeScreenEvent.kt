package dev.cloveclove.peppercheck.ui.screens.home

sealed class HomeScreenEvent {
    data object LoadTasks : HomeScreenEvent()
    data object RefreshTasks : HomeScreenEvent()
}