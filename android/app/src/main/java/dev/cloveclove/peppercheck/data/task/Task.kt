package dev.cloveclove.peppercheck.data.task

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Task(
    val id: String,
    @SerialName("tasker_id") 
    val taskerId: String,
    val title: String,
    val description: String?,
    val criteria: String?,
    @SerialName("due_date") 
    val dueDate: String?,
    @SerialName("fee_amount") 
    val feeAmount: Double?,
    @SerialName("fee_currency") 
    val feeCurrency: String?,
    val status: String,
    @SerialName("created_at") 
    val createdAt: String?,
    @SerialName("updated_at") 
    val updatedAt: String? = null
)
