package dev.cloveclove.peppercheck.domain.task

data class UpdateJudgementParams(
    val judgementId: String,
    val status: String,
    val comment: String
)