package dev.cloveclove.peppercheck.data.task

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// POST /tasks 用のリクエストデータクラス
@Serializable
data class TaskCreateRequest(
    @SerialName("tasker_id")
    val taskerId: String,
    val title: String,
    val description: String? = null,
    val criteria: String? = null,
    @SerialName("due_date")
    val dueDate: String? = null,
    @SerialName("fee_amount")
    val feeAmount: Double? = null,
    @SerialName("fee_currency")
    val feeCurrency: String? = null,
    val status: String
)