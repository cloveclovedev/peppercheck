package dev.cloveclove.peppercheck.domain.task

import android.net.Uri

data class SubmitEvidenceParams(
    val taskId: String,
    val evidenceId: String?, // 更新の場合はIDあり、新規作成の場合はnull
    val description: String,
    val assetIdsToDelete: List<String>, // 削除対象の既存アセットIDリスト
    val newImageUris: List<Uri>         // 新規アップロード対象の画像Uriリスト
)