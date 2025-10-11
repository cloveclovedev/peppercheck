package dev.cloveclove.peppercheck.repository

import dev.cloveclove.peppercheck.BuildConfig
import dev.cloveclove.peppercheck.data.judgement.Judgement
import dev.cloveclove.peppercheck.data.judgement.JudgementUpdateRequest
import dev.cloveclove.peppercheck.data.judgement.ConfirmJudgementRequest
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.get
import io.ktor.client.request.headers
import io.ktor.client.request.patch
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import io.ktor.http.isSuccess

class JudgementRepository(
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
        }
    }

    suspend fun getJudgements(taskId: String): Result<List<Judgement>> {
        return runCatching {
            val response = httpClient.get("$baseUrl/rest/v1/judgements_ext?task_id=eq.$taskId&select=*,profiles(*)") {
                addAuthHeaders()
            }

            val judgements: List<Judgement> = response.body()
            judgements
        }
    }

    suspend fun updateJudgement(judgementId: String, status: String? = null, comment: String? = null): Result<Unit> {
        return runCatching {
            val requestPayload = JudgementUpdateRequest(
                status = status,
                comment = comment
            )

            val response = httpClient.patch("$baseUrl/rest/v1/judgements?id=eq.$judgementId") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(requestPayload)
            }

            if (response.status.value !in 200..299) {
                throw IllegalStateException("Failed to update judgement: ${response.status}")
            }
        }
    }

    suspend fun confirmJudgement(judgementId: String): Result<Unit> {
        return runCatching {
            val response = httpClient.patch("$baseUrl/rest/v1/judgements?id=eq.$judgementId") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(mapOf("is_confirmed" to true))
            }
            
            if (!response.status.isSuccess()) {
                val errorBody = response.bodyAsText()
                throw Exception("Failed to confirm judgement: ${response.status}. Details: $errorBody")
            }
        }
    }

    suspend fun confirmJudgementAndRateReferee(
        taskId: String,
        judgementId: String,
        rateeId: String,
        rating: Int,
        comment: String?
    ): Result<Unit> {
        return runCatching {
            val requestPayload = ConfirmJudgementRequest(
                taskId = taskId,
                judgementId = judgementId,
                rateeId = rateeId,
                rating = rating,
                comment = comment
            )
            
            val response = httpClient.post("$baseUrl/rest/v1/rpc/confirm_judgement_and_rate_referee") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(requestPayload)
            }
            
            if (!response.status.isSuccess()) {
                val errorBody = response.bodyAsText()
                throw Exception("Failed to confirm judgement and rate referee: ${response.status}. Details: $errorBody")
            }
        }
    }

    suspend fun reopenJudgement(judgementId: String): Result<Unit> {
        return runCatching {
            val response = httpClient.post("$baseUrl/rest/v1/rpc/reopen_judgement") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(mapOf("p_judgement_id" to judgementId))
            }

            if (!response.status.isSuccess()) {
                val errorBody = response.bodyAsText()
                throw Exception("Failed to reopen judgement: ${response.status}. Details: $errorBody")
            }
        }
    }

    suspend fun confirmEvidenceTimeoutFromReferee(judgementId: String): Result<Unit> {
        return runCatching {
            val response = httpClient.post("$baseUrl/rest/v1/rpc/confirm_evidence_timeout_from_referee") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(mapOf("p_judgement_id" to judgementId))
            }

            if (!response.status.isSuccess()) {
                val errorBody = response.bodyAsText()
                throw Exception("Failed to confirm evidence timeout: ${response.status}. Details: $errorBody")
            }
        }
    }
}

