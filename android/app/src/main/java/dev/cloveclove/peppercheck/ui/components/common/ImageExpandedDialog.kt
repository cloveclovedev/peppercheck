package dev.cloveclove.peppercheck.ui.components.common

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil3.compose.AsyncImage

/**
 * 画像拡大表示ダイアログ
 * 
 * 画像をタップした際に表示される拡大表示用のモーダルダイアログです。
 * 角丸の画像を画面中央に表示し、背景をタップすることで閉じることができます。
 * 
 * @param imageUrl 表示する画像のURL。nullの場合はダイアログを表示しません
 * @param onDismiss ダイアログを閉じるときのコールバック
 */
@Composable
fun ImageExpandedDialog(
    imageUrl: String?,
    onDismiss: () -> Unit
) {
    if (imageUrl != null) {
        Dialog(
            onDismissRequest = onDismiss,
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.4f))
                    .clickable { onDismiss() },
                contentAlignment = Alignment.Center
            ) {
                AsyncImage(
                    model = imageUrl,
                    contentDescription = "拡大画像",
                    modifier = Modifier
                        .fillMaxWidth(0.85f)
                        .clip(RoundedCornerShape(16.dp))
                        .clickable(enabled = false) { }, // 画像自体のタップを無効化
                    contentScale = ContentScale.Fit
                )
            }
        }
    }
}