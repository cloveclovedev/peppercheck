package dev.cloveclove.peppercheck.ui.components.evidence

import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.components.common.AddImageButton
import dev.cloveclove.peppercheck.ui.components.common.BaseSection
import dev.cloveclove.peppercheck.ui.components.common.BaseTextField
import dev.cloveclove.peppercheck.ui.components.common.ImageItem
import dev.cloveclove.peppercheck.ui.components.common.PrimaryActionButton
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun SubmitEvidenceSection(
    description: String,
    onDescriptionChange: (String) -> Unit,
    initialImageUrls: List<String>,   // 既存の画像URLリスト
    newImageUris: List<Uri>,          // 新しい画像Uriリスト
    onAddImagesClick: () -> Unit,
    onRemoveInitialImage: (String) -> Unit, // URL削除用コールバック
    onRemoveNewImage: (Uri) -> Unit,        // Uri削除用コールバック
    isSubmitEnabled: Boolean,         // ★ 外部からバリデーション結果を受け取る
    isDueDatePassed: Boolean = false, // Due date チェック結果
    onSubmitClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    BaseSection(title = "Submit Evidence", modifier = modifier) {
        BaseTextField(
            value = description,
            onValueChange = onDescriptionChange,
            label = "Evidence description"
        )
        Spacer(modifier = Modifier.height(12.dp))
        
        val totalImageCount = initialImageUrls.size + newImageUris.size
        Text(
            text = "Images ($totalImageCount/5)",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Medium,
            color = TextBlack
        )
        Spacer(modifier = Modifier.height(8.dp))
        
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            // 既存の画像 (URL) を表示
            items(initialImageUrls) { url ->
                ImageItem(
                    imageUrl = url,
                    contentDescription = "Existing image",
                    onRemove = { onRemoveInitialImage(url) }
                )
            }
            
            // 新しく選択された画像 (Uri) を表示
            items(newImageUris) { uri ->
                ImageItem(
                    uri = uri,
                    contentDescription = "Selected image",
                    onRemove = { onRemoveNewImage(uri) }
                )
            }
            
            if (totalImageCount < 5) {
                item {
                    AddImageButton(onClick = onAddImagesClick)
                }
            }
        }
        
        Spacer(modifier = Modifier.height(12.dp))
        
        PrimaryActionButton(
            text = "Submit Evidence",
            enabled = isSubmitEnabled && !isDueDatePassed, // Due date チェックも含める
            onClick = onSubmitClick,
            modifier = Modifier.fillMaxWidth()
        )
        
        // Show due date warning if passed
        if (isDueDatePassed) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Due date has passed. Evidence cannot be submitted.",
                style = MaterialTheme.typography.bodySmall,
                color = TextBlack.copy(alpha = 0.6f),
                modifier = Modifier.fillMaxWidth(),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )
        }
    }
}
