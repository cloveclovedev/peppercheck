package dev.cloveclove.peppercheck.ui.components.common

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.ui.theme.BackGroundLight
import dev.cloveclove.peppercheck.ui.theme.TextBlack

/**
 * 基本セクションコンポーネント
 * 
 * PepperCheckアプリ全体で使用される統一されたセクション表示コンポーネント。
 * カードベースのレイアウトでタイトルとコンテンツを表示します。
 * 
 * @param title セクションのタイトル
 * @param modifier 追加のModifier
 * @param actions タイトル右側に表示するアクション（オプション）
 * @param content セクションの内容
 */
@Composable
fun BaseSection(
    title: String,
    modifier: Modifier = Modifier,
    actions: (@Composable RowScope.() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = BackGroundLight
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            // タイトル行
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium,
                    color = TextBlack,
                    modifier = Modifier.weight(1f)
                )
                
                actions?.invoke(this)
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            // コンテンツエリア
            content()
        }
    }
}