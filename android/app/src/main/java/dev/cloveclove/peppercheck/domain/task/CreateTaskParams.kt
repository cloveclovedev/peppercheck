package dev.cloveclove.peppercheck.domain.task

// UseCaseの責務（ドメイン）で必要な情報だけを定義
data class CreateTaskParams(
    val title: String,
    val description: String?,
    val criteria: String?,
    val dueDate: String?,
    val feeAmount: Double,
    val status: String,
    val selectedStrategies: List<String>
)