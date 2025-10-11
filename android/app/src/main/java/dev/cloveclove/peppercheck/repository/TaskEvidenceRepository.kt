package dev.cloveclove.peppercheck.repository

import dev.cloveclove.peppercheck.BuildConfig
import dev.cloveclove.peppercheck.data.evidence.TaskEvidence
import dev.cloveclove.peppercheck.data.evidence.TaskEvidenceAsset
import dev.cloveclove.peppercheck.data.evidence.TaskEvidenceCreateRequest
import dev.cloveclove.peppercheck.data.evidence.TaskEvidenceUpdateRequest
import dev.cloveclove.peppercheck.data.evidence.TaskEvidenceAssetCreateRequest
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.headers
import io.ktor.client.request.patch
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType

class TaskEvidenceRepository(
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

    suspend fun getTaskEvidence(taskId: String): Result<TaskEvidence> {
        return runCatching {
            val response = httpClient.get("$baseUrl/rest/v1/task_evidences?task_id=eq.$taskId&select=*,task_evidence_assets(*)") {
                addAuthHeaders()
            }

            val evidences = response.body<List<TaskEvidence>>()
            evidences.firstOrNull() ?: throw NoSuchElementException("Task evidence for task $taskId not found")
        }
    }

    suspend fun createTaskEvidence(
        taskId: String,
        description: String,
        status: String = "pending_upload"
    ): Result<TaskEvidence> {
        return runCatching {
            val requestPayload = TaskEvidenceCreateRequest(
                taskId = taskId,
                description = description,
                status = status
            )

            val response = httpClient.post("$baseUrl/rest/v1/task_evidences") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(requestPayload)
            }

            if (response.status.value in 200..299) {
                val evidences = response.body<List<TaskEvidence>>()
                evidences.firstOrNull() ?: throw IllegalStateException("Failed to create task evidence")
            } else {
                throw IllegalStateException("Failed to create task evidence: ${response.status}")
            }
        }
    }

    suspend fun updateTaskEvidence(
        evidenceId: String,
        description: String? = null,
        status: String? = null
    ): Result<TaskEvidence> {
        return runCatching {
            val requestPayload = TaskEvidenceUpdateRequest(
                description = description,
                status = status
            )

            val response = httpClient.patch("$baseUrl/rest/v1/task_evidences?id=eq.$evidenceId") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(requestPayload)
            }

            if (response.status.value in 200..299) {
                val evidences = response.body<List<TaskEvidence>>()
                evidences.firstOrNull() ?: throw IllegalStateException("Failed to update task evidence")
            } else {
                throw IllegalStateException("Failed to update task evidence: ${response.status}")
            }
        }
    }

    suspend fun createTaskEvidenceAsset(
        evidenceId: String,
        fileUrl: String,
        fileSizeBytes: Long? = null,
        contentType: String? = null,
        publicUrl: String? = null,
        processingStatus: String = "ready" // MVP: アップロード成功後は即座にready
    ): Result<TaskEvidenceAsset> {
        return runCatching {
            val requestPayload = TaskEvidenceAssetCreateRequest(
                evidenceId = evidenceId,
                fileUrl = fileUrl,
                fileSizeBytes = fileSizeBytes,
                contentType = contentType,
                publicUrl = publicUrl,
                processingStatus = processingStatus
            )

            val response = httpClient.post("$baseUrl/rest/v1/task_evidence_assets") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(requestPayload)
            }

            if (response.status.value in 200..299) {
                val assets = response.body<List<TaskEvidenceAsset>>()
                assets.firstOrNull() ?: throw IllegalStateException("Failed to create task evidence asset")
            } else {
                throw IllegalStateException("Failed to create task evidence asset: ${response.status}")
            }
        }
    }

    suspend fun deleteTaskEvidence(evidenceId: String): Result<Unit> {
        return runCatching {
            val response = httpClient.delete("$baseUrl/rest/v1/task_evidences?id=eq.$evidenceId") {
                addAuthHeaders()
            }

            if (response.status.value !in 200..299) {
                throw IllegalStateException("Failed to delete task evidence: ${response.status}")
            }
        }
    }

    suspend fun deleteTaskEvidenceAsset(assetId: String): Result<Unit> {
        return runCatching {
            val response = httpClient.delete("$baseUrl/rest/v1/task_evidence_assets?id=eq.$assetId") {
                addAuthHeaders()
            }

            if (response.status.value !in 200..299) {
                throw IllegalStateException("Failed to delete task evidence asset: ${response.status}")
            }
        }
    }
}

