package dev.cloveclove.peppercheck.repository

import dev.cloveclove.peppercheck.BuildConfig
import dev.cloveclove.peppercheck.data.task.Task
import dev.cloveclove.peppercheck.data.task.TaskCreateRequest
import dev.cloveclove.peppercheck.data.task.TaskUpdateRequest
import dev.cloveclove.peppercheck.data.task.RefereeTaskResponse
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.get
import io.ktor.client.request.headers
import io.ktor.client.request.patch
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType

class TaskRepository(
    private val httpClient: HttpClient,
    private val authRepository: AuthRepository
) {
    private val baseUrl = BuildConfig.GATEWAY_URL

    // Common auth headers for all API requests
    private suspend fun HttpRequestBuilder.addAuthHeaders() {
        val authToken = authRepository.getCurrentAuthToken()
        val apiKey = authRepository.getApiKey()
        headers {
            append(HttpHeaders.Authorization, "Bearer $authToken")
            append("apikey", apiKey)
            append("Prefer", "return=representation")
        }
    }

    suspend fun getTaskById(taskId: String): Result<Task> {
        return runCatching {
            val response = httpClient.get("$baseUrl/rest/v1/tasks?id=eq.$taskId") {
                addAuthHeaders()
            }

            val tasks: List<Task> = response.body()
            tasks.firstOrNull() ?: throw NoSuchElementException("Task with id $taskId not found")
        }
    }

    suspend fun createTask(
        title: String,
        description: String? = null,
        criteria: String? = null,
        dueDate: String? = null,
        feeAmount: Double? = null,
        feeCurrency: String? = null,
        status: String
    ): Result<Task> {
        return runCatching {
            val currentUserId = authRepository.getCurrentUserId()

            val requestPayload = TaskCreateRequest(
                taskerId = currentUserId,
                title = title,
                description = description,
                criteria = criteria,
                dueDate = dueDate,
                feeAmount = feeAmount,
                feeCurrency = feeCurrency,
                status = status
            )

            val response = httpClient.post("$baseUrl/rest/v1/tasks") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(requestPayload)
            }

            if (response.status.value in 200..299) {
                val tasks: List<Task> = response.body()
                tasks.firstOrNull() ?: throw IllegalStateException("Failed to create task")
            } else {
                throw IllegalStateException("Failed to create task: ${response.status}")
            }
        }
    }

    suspend fun updateTask(
        taskId: String,
        title: String? = null,
        description: String? = null,
        criteria: String? = null,
        dueDate: String? = null,
        feeAmount: Double? = null,
        feeCurrency: String? = null,
        status: String? = null
    ): Result<Task> {
        return runCatching {
            val requestPayload = TaskUpdateRequest(
                title = title,
                description = description,
                criteria = criteria,
                dueDate = dueDate,
                feeAmount = feeAmount,
                feeCurrency = feeCurrency,
                status = status
            )

            val response = httpClient.patch("$baseUrl/rest/v1/tasks?id=eq.$taskId") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(requestPayload)
            }

            if (response.status.value in 200..299) {
                val tasks: List<Task> = response.body()
                tasks.firstOrNull() ?: throw IllegalStateException("Failed to update task")
            } else {
                throw IllegalStateException("Failed to update task: ${response.status}")
            }
        }
    }

    suspend fun getActiveUserTasks(): Result<List<Task>> {
        return runCatching {
            val currentUserId = authRepository.getCurrentUserId()

            val response = httpClient.get("$baseUrl/rest/v1/tasks?tasker_id=eq.$currentUserId&status=neq.closed") {
                addAuthHeaders()
            }

            val tasks: List<Task> = response.body()
            tasks
        }
    }

    suspend fun getActiveRefereeTasks(): Result<List<Task>> {
        return runCatching {
            val response = httpClient.post("$baseUrl/rest/v1/rpc/get_active_referee_tasks") {
                addAuthHeaders()
            }

            val refereeResponses = response.body<List<RefereeTaskResponse>?>() ?: emptyList()

            // Convert RefereeTaskResponse back to Task format for existing UI compatibility
            refereeResponses.map { response ->
                response.task
            }
        }
    }
}

