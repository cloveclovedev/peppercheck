package dev.cloveclove.peppercheck.ui.components.common

import android.net.Uri
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import dev.cloveclove.peppercheck.ui.theme.AccentBlueLight

@Composable
fun ImageItem(
    imageUrl: String? = null,
    uri: Uri? = null,
    contentDescription: String = "Image",
    onClick: (() -> Unit)? = null,
    onRemove: (() -> Unit)? = null,
    size: Dp = 72.dp
) {
    Box(
        modifier = Modifier.size(size)
    ) {
        // Determine image source (URI takes priority over URL)
        val imageModel = uri ?: imageUrl
        
        AsyncImage(
            model = imageModel,
            contentDescription = contentDescription,
            modifier = Modifier
                .size(size)
                .clip(RoundedCornerShape(8.dp))
                .border(
                    1.dp,
                    AccentBlueLight.copy(alpha = 0.3f),
                    RoundedCornerShape(8.dp)
                )
                .let { modifier ->
                    if (onClick != null) {
                        modifier.clickable { onClick() }
                    } else {
                        modifier
                    }
                },
            contentScale = ContentScale.Crop
        )
        
        // Show remove button if onRemove is provided
        if (onRemove != null) {
            DeleteButton(
                onClick = onRemove,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = 6.dp, y = (-4).dp)
            )
        }
    }
}