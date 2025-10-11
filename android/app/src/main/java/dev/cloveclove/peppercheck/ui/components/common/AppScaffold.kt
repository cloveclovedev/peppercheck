package dev.cloveclove.peppercheck.ui.components.common

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import dev.cloveclove.peppercheck.navigation.Screen
import dev.cloveclove.peppercheck.ui.theme.AccentYellow
import dev.cloveclove.peppercheck.ui.theme.BackGroundDark
import dev.cloveclove.peppercheck.ui.theme.TextBlack

@Composable
fun AppScaffold(
    navController: NavController,
    currentScreenRoute: String,
    content: @Composable (PaddingValues) -> Unit
) {
    Scaffold(
        containerColor = Color.Transparent,
        bottomBar = {
            Box(
                modifier = Modifier
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(BackGroundDark)
            ) {
                NavigationBar(
                    containerColor = BackGroundDark,
                    contentColor = TextBlack,
                    windowInsets = WindowInsets(0.dp)
                ) {
                    NavigationBarItem(
                        icon = { Icon(Icons.Default.Home, contentDescription = "Home") },
                        label = { Text("Home") },
                        selected = currentScreenRoute == Screen.Home.route,
                        onClick = { navController.navigate(Screen.Home.route) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = TextBlack,
                            selectedTextColor = TextBlack,
                            indicatorColor = AccentYellow,
                            unselectedIconColor = TextBlack,
                            unselectedTextColor = TextBlack
                        )
                    )
                    NavigationBarItem(
                        icon = { Icon(Icons.Default.Person, contentDescription = "Profile") },
                        label = { Text("Profile") },
                        selected = currentScreenRoute == Screen.Profile.route,
                        onClick = { navController.navigate(Screen.Profile.route) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = TextBlack,
                            selectedTextColor = TextBlack,
                            indicatorColor = AccentYellow,
                            unselectedIconColor = TextBlack,
                            unselectedTextColor = TextBlack
                        )
                    )
                }
            }
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { navController.navigate(Screen.CreateTask.route) },
                containerColor = AccentYellow,
                contentColor = TextBlack
            ) {
                Icon(Icons.Default.Add, contentDescription = "Create Task")
            }
        },
        content = content
    )
}