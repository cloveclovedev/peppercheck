package dev.cloveclove.peppercheck.repository

import dev.cloveclove.peppercheck.BuildConfig
import dev.cloveclove.peppercheck.data.profile.Profile
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.get
import io.ktor.client.request.headers
import io.ktor.http.HttpHeaders

class ProfileRepository(
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

    suspend fun getProfile(profileId: String): Result<Profile> {
        return runCatching {
            val response = httpClient.get("$baseUrl/rest/v1/profiles?id=eq.$profileId") {
                addAuthHeaders()
            }

            val profiles: List<Profile> = response.body()
            profiles.firstOrNull() ?: throw NoSuchElementException("Profile with id $profileId not found")
        }
    }

}
