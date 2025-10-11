package dev.cloveclove.peppercheck.data.task

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// PATCH /tasks?id=eq.{taskId} 用のリクエストデータクラス
// PATCHでは更新したいフィールドのみを送るため、すべてオプショナルにする
@Serializable
data class TaskUpdateRequest(
    val title: String? = null,
    val description: String? = null,
    val criteria: String? = null,
    @SerialName("due_date")
    val dueDate: String? = null,
    @SerialName("fee_amount")
    val feeAmount: Double? = null,
    @SerialName("fee_currency")
    val feeCurrency: String? = null,
    val status: String? = null
)