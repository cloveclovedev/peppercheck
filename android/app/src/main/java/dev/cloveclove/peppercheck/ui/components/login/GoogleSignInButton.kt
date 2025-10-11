package dev.cloveclove.peppercheck.ui.components.login

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import dev.cloveclove.peppercheck.R

@Composable
fun GoogleSignInButton(
    onClick: () -> Unit,
    enabled: Boolean = true
) {
    Box(
        modifier = Modifier
            .widthIn(max = 200.dp)
            .aspectRatio(4.725f)
            .clickable(enabled = enabled, onClick = onClick)
    ) {
        Icon(
            painter = painterResource(R.drawable.android_neutral_rd_ctn),
            contentDescription = "Continue with Google",
            modifier = Modifier.fillMaxSize(),
            tint = Color.Unspecified
        )
    }
}