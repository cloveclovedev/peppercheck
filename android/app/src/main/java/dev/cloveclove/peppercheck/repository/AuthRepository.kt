package dev.cloveclove.peppercheck.repository

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken

class AuthRepository(private val supabaseClient: SupabaseClient) {

    // Get current authenticated user ID
    fun getCurrentUserId(): String {
        return supabaseClient.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("User not authenticated")
    }

    // Get current authentication token
    fun getCurrentAuthToken(): String {
        return supabaseClient.auth.currentSessionOrNull()?.accessToken
            ?: throw IllegalStateException("Not authenticated")
    }

    // Get Supabase API key
    fun getApiKey(): String {
        return supabaseClient.supabaseKey
    }

    // Sign in with Google using ID token
    suspend fun signInWithGoogle(idToken: String, rawNonce: String): Result<Unit> {
        return runCatching {
            supabaseClient.auth.signInWith(IDToken) {
                this.idToken = idToken
                provider = Google
                nonce = rawNonce
            }
        }
    }
}