package dev.cloveclove.peppercheck.repository

import dev.cloveclove.peppercheck.BuildConfig
import dev.cloveclove.peppercheck.data.payout.PayoutRequestPayload
import dev.cloveclove.peppercheck.data.payout.PayoutRequestResponse
import dev.cloveclove.peppercheck.data.payout.PayoutSummary
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.headers
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.HttpHeaders

class PayoutRepository(
    private val httpClient: HttpClient,
    private val authRepository: AuthRepository
) {
    private val baseUrl = BuildConfig.GATEWAY_URL

    suspend fun requestPayout(amountMinor: Long, currencyCode: String = "JPY"): Result<PayoutRequestResponse> {
        return runCatching {
            val authToken = authRepository.getCurrentAuthToken()
            val response = httpClient.post("$baseUrl/functions/v1/payout-request") {
                headers {
                    append(HttpHeaders.Authorization, "Bearer $authToken")
                    append(HttpHeaders.ContentType, "application/json")
                }
                setBody(PayoutRequestPayload(amountMinor = amountMinor, currencyCode = currencyCode))
            }

            if (response.status.value !in 200..299) {
                throw IllegalStateException("Failed to create payout request: ${response.status}")
            }

            response.body<PayoutRequestResponse>()
        }
    }

    suspend fun getPayoutSummary(): Result<PayoutSummary> {
        return runCatching {
            val authToken = authRepository.getCurrentAuthToken()
            val response = httpClient.get("$baseUrl/functions/v1/payout-summary") {
                headers {
                    append(HttpHeaders.Authorization, "Bearer $authToken")
                }
            }

            if (response.status.value !in 200..299) {
                throw IllegalStateException("Failed to fetch payout summary: ${response.status}")
            }

            response.body<PayoutSummary>()
        }
    }
}
