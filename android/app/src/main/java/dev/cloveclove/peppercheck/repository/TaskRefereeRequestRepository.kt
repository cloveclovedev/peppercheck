package dev.cloveclove.peppercheck.repository

import dev.cloveclove.peppercheck.BuildConfig
import dev.cloveclove.peppercheck.data.referee_request.TaskRefereeRequest
import dev.cloveclove.peppercheck.data.referee_request.TaskRefereeRequestCreateRequest
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.get
import io.ktor.client.request.headers
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType

class TaskRefereeRequestRepository(
    private val httpClient: HttpClient,
    private val authRepository: AuthRepository
) {
    private val baseUrl = BuildConfig.GATEWAY_URL

    private suspend fun HttpRequestBuilder.addAuthHeaders() {
        val authToken = authRepository.getCurrentAuthToken()
        val apiKey = authRepository.getApiKey()
        headers {
            append(HttpHeaders.Authorization, "Bearer $authToken")
            append("apikey", apiKey)
            append("Prefer", "return=representation")
        }
    }

    suspend fun createTaskRefereeRequest(
        taskId: String,
        matchingStrategy: String,
        preferredRefereeId: String? = null
    ): Result<TaskRefereeRequest> {
        return runCatching {
            val requestPayload = TaskRefereeRequestCreateRequest(
                taskId = taskId,
                matchingStrategy = matchingStrategy,
                preferredRefereeId = preferredRefereeId,
                status = "pending"
            )

            val response = httpClient.post("$baseUrl/rest/v1/task_referee_requests") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(requestPayload)
            }

            if (response.status.value !in 200..299) {
                throw IllegalStateException("Failed to create referee request: ${response.status}")
            }

            val requests: List<TaskRefereeRequest> = response.body()
            requests.firstOrNull() ?: throw IllegalStateException("No referee request returned")
        }
    }

    suspend fun getTaskRefereeRequests(taskId: String): Result<List<TaskRefereeRequest>> {
        return runCatching {
            val response = httpClient.get("$baseUrl/rest/v1/task_referee_requests?task_id=eq.$taskId") {
                addAuthHeaders()
            }

            val requests: List<TaskRefereeRequest> = response.body()
            requests
        }
    }
}

