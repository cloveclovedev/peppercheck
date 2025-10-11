package dev.cloveclove.peppercheck.data.judgement

import dev.cloveclove.peppercheck.data.profile.Profile
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Judgement(
    val id: String,
    @SerialName("task_id") 
    val taskId: String,
    @SerialName("referee_id") 
    val refereeId: String,
    val status: String,
    val comment: String?,
    @SerialName("is_confirmed")
    val isConfirmed: Boolean = false,
    @SerialName("reopen_count")
    val reopenCount: Int = 0,
    @SerialName("can_reopen")
    val canReopen: Boolean = false,
    @SerialName("is_evidence_timeout_confirmed")
    val isEvidenceTimeoutConfirmed: Boolean = false,
    @SerialName("created_at") 
    val createdAt: String,
    @SerialName("updated_at") 
    val updatedAt: String,
    
    // APIの `select=*,profiles(*)` の結果を格納するための受け皿
    // 関連データがない場合もあるため、null許容にするのが安全
    val profiles: Profile? = null
)

