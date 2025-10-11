package dev.cloveclove.peppercheck.data.r2

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class GenerateUploadUrlRequest(
    @SerialName("task_id") 
    val taskId: String,
    val filename: String,
    @SerialName("content_type") 
    val contentType: String,
    @SerialName("file_size_bytes") 
    val fileSizeBytes: Long,
    val kind: String
)

@Serializable
data class GenerateUploadUrlResponse(
    @SerialName("upload_url") 
    val uploadUrl: String,
    @SerialName("r2_key") 
    val r2Key: String,
    @SerialName("expires_in") 
    val expiresIn: Int
)

@Serializable
data class UploadResult(
    @SerialName("r2_key") 
    val r2Key: String,
    @SerialName("public_url") 
    val publicUrl: String
)

