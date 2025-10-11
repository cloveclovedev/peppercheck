package dev.cloveclove.peppercheck.data.profile

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Profile(
    val id: String,
    val username: String? = null,
    @SerialName("avatar_url") 
    val avatarUrl: String? = null,
    @SerialName("created_at") 
    val createdAt: String? = null,
    @SerialName("stripe_connect_account_id") 
    val stripeConnectAccountId: String? = null,
    @SerialName("updated_at") 
    val updatedAt: String? = null,
    val timezone: String? = null
)