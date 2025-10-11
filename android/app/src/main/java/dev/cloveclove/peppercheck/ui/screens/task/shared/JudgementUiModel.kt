package dev.cloveclove.peppercheck.ui.screens.task.shared

import dev.cloveclove.peppercheck.data.judgement.Judgement

/**
 * Judgement情報をUIに表示するためのモデル。
 */
data class JudgementUiModel(
    val id: String,
    val refereeId: String,
    val refereeName: String,
    val refereeAvatarUrl: String?,
    val status: String,
    val comment: String?,
    val isConfirmed: Boolean = false,
    val canReopen: Boolean = false,
    val reopenCount: Int = 0,
    val isEvidenceTimeoutConfirmed: Boolean = false
)

/**
 * data層のJudgementモデルを、UI層のJudgementUiModelに変換する拡張関数。
 */
fun Judgement.toUiModel(): JudgementUiModel {
    return JudgementUiModel(
        id = this.id,
        refereeId = this.refereeId,
        refereeName = this.profiles?.username ?: "Unknown Referee",
        refereeAvatarUrl = this.profiles?.avatarUrl,
        status = this.status,
        comment = this.comment,
        isConfirmed = this.isConfirmed,
        canReopen = this.canReopen,
        reopenCount = this.reopenCount,
        isEvidenceTimeoutConfirmed = this.isEvidenceTimeoutConfirmed
    )
}

/**
 * JudgementUiModelの状態に基づく拡張プロパティ
 */
val JudgementUiModel.canBeConfirmed: Boolean
    get() = !isConfirmed && status in listOf("approved", "rejected", "judgement_timeout", "evidence_timeout")