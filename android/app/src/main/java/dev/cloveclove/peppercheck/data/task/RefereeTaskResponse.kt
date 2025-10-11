package dev.cloveclove.peppercheck.data.task

import dev.cloveclove.peppercheck.data.judgement.Judgement
import dev.cloveclove.peppercheck.data.profile.Profile
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RefereeTaskResponse(
    val task: Task, // RPC returns 'task' field
    val judgement: Judgement,
    @SerialName("tasker_profile")
    val taskerProfile: Profile
)

