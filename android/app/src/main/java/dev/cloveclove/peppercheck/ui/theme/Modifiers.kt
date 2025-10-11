package dev.cloveclove.peppercheck.ui.theme

import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * LazyColumnなど、画面の主要なコンテンツに使用する標準のpadding。
 * アプリ全体のリスト画面の余白を統一します。
 */
fun Modifier.standardScreenPadding(): Modifier = this.then(
    padding(start = 16.dp, end = 16.dp, bottom = 16.dp, top = 4.dp)
)