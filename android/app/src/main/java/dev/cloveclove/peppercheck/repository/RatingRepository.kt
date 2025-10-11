package dev.cloveclove.peppercheck.repository

import dev.cloveclove.peppercheck.BuildConfig
import dev.cloveclove.peppercheck.data.rating.RatingHistory
import dev.cloveclove.peppercheck.data.rating.RatingHistoryCreateRequest
import dev.cloveclove.peppercheck.domain.rating.RatingRepository
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.get
import io.ktor.client.request.headers
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import io.ktor.http.isSuccess

class ApiRatingRepository(
    private val httpClient: HttpClient,
    private val authRepository: AuthRepository
) : RatingRepository {
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

    override suspend fun addRatingHistory(
        taskId: String,
        judgementId: String,
        rateeUserId: String,
        ratingType: String,
        rating: Int,
        comment: String?
    ): Result<Unit> {
        return runCatching {
            val requestPayload = RatingHistoryCreateRequest(
                rateeId = rateeUserId,
                taskId = taskId,
                judgementId = judgementId,
                ratingType = ratingType,
                rating = rating,
                comment = comment
            )

            val response = httpClient.post("$baseUrl/rest/v1/rating_histories") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(requestPayload)
            }

            if (!response.status.isSuccess()) {
                val errorBody = response.bodyAsText()
                throw Exception("Failed to add rating history: ${response.status}. Details: $errorBody")
            }
        }
    }

    override suspend fun getRatingsByTaskerForTask(taskId: String): Result<List<RatingHistory>> {
        return runCatching {
            val currentUserId = authRepository.getCurrentUserId()
            
            val response = httpClient.get("$baseUrl/rest/v1/rating_histories?task_id=eq.$taskId&rater_id=eq.$currentUserId&rating_type=eq.referee") {
                addAuthHeaders()
            }

            response.body()
        }
    }
}