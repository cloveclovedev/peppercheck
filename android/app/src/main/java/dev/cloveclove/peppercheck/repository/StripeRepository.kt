package dev.cloveclove.peppercheck.repository

import dev.cloveclove.peppercheck.BuildConfig
import dev.cloveclove.peppercheck.data.stripe.StripeAccount
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.get
import io.ktor.client.request.headers
import io.ktor.http.HttpHeaders

class StripeRepository(
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

    suspend fun getStripeAccount(): Result<StripeAccount?> {
        return runCatching {
            val currentUserId = authRepository.getCurrentUserId()
            val response = httpClient.get("$baseUrl/rest/v1/stripe_accounts?profile_id=eq.$currentUserId") {
                addAuthHeaders()
            }

            val stripeAccounts: List<StripeAccount> = response.body()
            stripeAccounts.firstOrNull()
        }
    }
}
