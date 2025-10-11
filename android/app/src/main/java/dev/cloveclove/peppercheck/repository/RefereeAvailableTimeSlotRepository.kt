package dev.cloveclove.peppercheck.repository

import dev.cloveclove.peppercheck.BuildConfig
import dev.cloveclove.peppercheck.data.referee_available_time_slot.RefereeAvailableTimeSlot
import dev.cloveclove.peppercheck.data.referee_available_time_slot.RefereeAvailableTimeSlotCreateRequest
import dev.cloveclove.peppercheck.data.referee_available_time_slot.RefereeAvailableTimeSlotUpdateRequest
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

class RefereeAvailableTimeSlotRepository(
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

    suspend fun getUserAvailableTimeSlots(): Result<List<RefereeAvailableTimeSlot>> {
        return runCatching {
            val currentUserId = authRepository.getCurrentUserId()

            val response = httpClient.get("$baseUrl/rest/v1/referee_available_time_slots?user_id=eq.$currentUserId") {
                addAuthHeaders()
            }

            val availableTimeSlots: List<RefereeAvailableTimeSlot> = response.body()
            availableTimeSlots
        }
    }

    suspend fun getAvailableTimeSlotById(timeSlotId: String): Result<RefereeAvailableTimeSlot> {
        return runCatching {
            val response = httpClient.get("$baseUrl/rest/v1/referee_available_time_slots?id=eq.$timeSlotId") {
                addAuthHeaders()
            }

            val availableTimeSlots: List<RefereeAvailableTimeSlot> = response.body()
            availableTimeSlots.firstOrNull() ?: throw NoSuchElementException("Available time slot with id $timeSlotId not found")
        }
    }

    suspend fun createAvailableTimeSlot(
        dow: Int,
        startMin: Int,
        endMin: Int,
        isActive: Boolean = true
    ): Result<RefereeAvailableTimeSlot> {
        return runCatching {
            val currentUserId = authRepository.getCurrentUserId()

            val requestPayload = RefereeAvailableTimeSlotCreateRequest(
                userId = currentUserId,
                dow = dow,
                startMin = startMin,
                endMin = endMin,
                isActive = isActive
            )

            val response = httpClient.post("$baseUrl/rest/v1/referee_available_time_slots") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(requestPayload)
            }

            if (response.status.value !in 200..299) {
                throw IllegalStateException("Failed to create available time slot: ${response.status}")
            }

            val availableTimeSlots: List<RefereeAvailableTimeSlot> = response.body()
            availableTimeSlots.firstOrNull() ?: throw IllegalStateException("No available time slot returned")
        }
    }

    suspend fun updateAvailableTimeSlot(
        timeSlotId: String,
        dow: Int? = null,
        startMin: Int? = null,
        endMin: Int? = null,
        isActive: Boolean? = null
    ): Result<RefereeAvailableTimeSlot> {
        return runCatching {
            val requestPayload = RefereeAvailableTimeSlotUpdateRequest(
                dow = dow,
                startMin = startMin,
                endMin = endMin,
                isActive = isActive
            )

            val response = httpClient.patch("$baseUrl/rest/v1/referee_available_time_slots?id=eq.$timeSlotId") {
                addAuthHeaders()
                contentType(ContentType.Application.Json)
                setBody(requestPayload)
            }

            if (response.status.value !in 200..299) {
                throw IllegalStateException("Failed to update available time slot: ${response.status}")
            }

            val availableTimeSlots: List<RefereeAvailableTimeSlot> = response.body()
            availableTimeSlots.firstOrNull() ?: throw IllegalStateException("No available time slot returned")
        }
    }

    suspend fun deleteAvailableTimeSlot(timeSlotId: String): Result<Unit> {
        return runCatching {
            val response = httpClient.delete("$baseUrl/rest/v1/referee_available_time_slots?id=eq.$timeSlotId") {
                addAuthHeaders()
            }

            if (response.status.value !in 200..299) {
                throw IllegalStateException("Failed to delete available time slot: ${response.status}")
            }
        }
    }

}