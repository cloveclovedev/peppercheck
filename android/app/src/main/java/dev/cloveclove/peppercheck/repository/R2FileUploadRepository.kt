package dev.cloveclove.peppercheck.repository

import android.content.ContentResolver
import android.net.Uri
import dev.cloveclove.peppercheck.BuildConfig
import dev.cloveclove.peppercheck.data.r2.GenerateUploadUrlRequest
import dev.cloveclove.peppercheck.data.r2.GenerateUploadUrlResponse
import dev.cloveclove.peppercheck.data.r2.UploadResult
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.headers
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class R2FileUploadRepository(
    private val httpClient: HttpClient,
    private val authRepository: AuthRepository,
    private val contentResolver: ContentResolver
) {
    private val baseUrl = BuildConfig.GATEWAY_URL

    suspend fun generateUploadUrl(request: GenerateUploadUrlRequest): Result<GenerateUploadUrlResponse> {
        return runCatching {
            val authToken = authRepository.getCurrentAuthToken()

            val response = httpClient.post("$baseUrl/functions/v1/generate-upload-url") {
                headers {
                    append(HttpHeaders.Authorization, "Bearer $authToken")
                }
                contentType(ContentType.Application.Json)
                setBody(request)
            }

            if (response.status.value in 200..299) {
                response.body<GenerateUploadUrlResponse>()
            } else {
                throw IllegalStateException("Failed to generate upload URL: ${response.status}")
            }
        }
    }

    suspend fun uploadFileWithGeneratedUploadUrl(
        uploadUrl: String,
        fileUri: Uri,
        contentType: String
    ): Result<Unit> {
        return runCatching {
            withContext(Dispatchers.IO) {
                val inputStream = contentResolver.openInputStream(fileUri)
                    ?: throw IllegalStateException("Cannot open file input stream")

                val response = httpClient.put(uploadUrl) {
                    headers {
                        append(HttpHeaders.ContentType, contentType)
                    }
                    setBody(inputStream.readBytes())
                }

                inputStream.close()
                
                if (response.status.value !in 200..299) {
                    throw IllegalStateException("Failed to upload file: ${response.status}")
                }
            }
        }
    }


    suspend fun getFileSize(fileUri: Uri): Result<Long> {
        return runCatching {
            withContext(Dispatchers.IO) {
                contentResolver.openFileDescriptor(fileUri, "r")?.use { pfd ->
                    pfd.statSize
                } ?: throw IllegalStateException("Cannot open file descriptor")
            }
        }
    }

    suspend fun getContentType(fileUri: Uri): Result<String> {
        return runCatching {
            contentResolver.getType(fileUri) ?: throw IllegalStateException("Cannot determine content type")
        }
    }

    fun getFileName(fileUri: Uri): Result<String> {
        return runCatching {
            contentResolver.query(fileUri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (cursor.moveToFirst() && nameIndex >= 0) {
                    cursor.getString(nameIndex)
                } else {
                    null
                }
            } ?: fileUri.lastPathSegment ?: "unknown_file"
        }
    }

    /**
     * ファイルの完全なアップロードプロセス（MVP版: 即座にpublic_url生成）
     * 1. アップロードURL生成
     * 2. ファイルアップロード
     * 3. 成功時にR2キーとpublic URLを返す
     */
    suspend fun uploadFile(
        taskId: String,
        fileUri: Uri,
        kind: String,
        filename: String? = null
    ): Result<UploadResult> {
        return runCatching {
            // ファイル情報の取得
            val actualFilename = filename ?: getFileName(fileUri).getOrThrow()
            val contentType = getContentType(fileUri).getOrThrow()
            val fileSize = getFileSize(fileUri).getOrThrow()

            // アップロードURL生成リクエスト
            val uploadRequest = GenerateUploadUrlRequest(
                taskId = taskId,
                filename = actualFilename,
                contentType = contentType,
                fileSizeBytes = fileSize,
                kind = kind
            )

            // 署名付きURL生成
            val uploadResponse = generateUploadUrl(uploadRequest).getOrThrow()

            // ファイルアップロード
            uploadFileWithGeneratedUploadUrl(uploadResponse.uploadUrl, fileUri, contentType).getOrThrow()

            // MVP: 即座にpublic URLを生成して返す
            val publicUrl = generatePublicUrl(uploadResponse.r2Key)
            UploadResult(
                r2Key = uploadResponse.r2Key,
                publicUrl = publicUrl
            )
        }
    }

    /**
     * MVP: R2キーからpublic URLを即座に生成
     * evidence/2025/08/03/uuid.jpg → https://file.peppercheck.com/evidence/2025/08/03/uuid.jpg
     */
    private fun generatePublicUrl(r2Key: String): String {
        return "https://file.peppercheck.com/$r2Key"
    }
}

