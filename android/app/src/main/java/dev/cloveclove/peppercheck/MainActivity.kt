package dev.cloveclove.peppercheck

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.navigation.compose.rememberNavController
import dev.cloveclove.peppercheck.di.ViewModelFactory
import dev.cloveclove.peppercheck.navigation.AppNavHost
import dev.cloveclove.peppercheck.navigation.Screen
import dev.cloveclove.peppercheck.ui.theme.PeppercheckTheme
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.launch


class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            PeppercheckTheme {
                PeppercheckApp()
            }
        }
    }
}

@Composable
fun PeppercheckApp() {
    // Applicationインスタンスを取得し、AppContainerにアクセス
    val application = LocalContext.current.applicationContext as PeppercheckApplication
    val container = application.container
    val supabase = container.supabaseClient

    val navController = rememberNavController()
    val coroutineScope = rememberCoroutineScope()
    val isLoggedIn = remember { mutableStateOf<Boolean?>(null) }

    LaunchedEffect(Unit) {
        coroutineScope.launch {
            val session = supabase.auth.currentSessionOrNull()
            isLoggedIn.value = session != null
        }
    }

    when (isLoggedIn.value) {
        null -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        true, false -> {
            val startDestination = if (isLoggedIn.value == true) {
                Screen.Home.route
            } else {
                Screen.Login.route
            }

            Box(modifier = Modifier.fillMaxSize()) {
                Image(
                    painter = painterResource(R.drawable.paper_texture),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.White.copy(alpha = 0.2f))
                )

                Scaffold(
                    containerColor = Color.Transparent,
                    modifier =  Modifier.fillMaxSize()
                ) { innerPadding ->
                    AppNavHost(
                        navController = navController,
                        startDestination = startDestination,
                        modifier = Modifier.padding(innerPadding),
                        factory = ViewModelFactory(container) // ViewModelFactoryを渡す
                    )
                }
            }
        }
    }
}
