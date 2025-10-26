package com.barqnet.android.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.barqnet.android.ui.screens.HomeScreen
import com.barqnet.android.ui.screens.ImportScreen
import com.barqnet.android.ui.screens.SettingsScreen
import com.barqnet.android.viewmodel.RealVPNViewModel

sealed class Screen(val route: String) {
    object Home : Screen("home")
    object Import : Screen("import")
    object Settings : Screen("settings")
}

@Composable
fun BarqNetNavHost(vpnViewModel: RealVPNViewModel) {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = Screen.Home.route
    ) {
        composable(Screen.Home.route) {
            HomeScreen(
                vpnViewModel = vpnViewModel,
                onNavigateToSettings = {
                    navController.navigate(Screen.Settings.route)
                },
                onNavigateToImport = {
                    navController.navigate(Screen.Import.route)
                }
            )
        }

        composable(Screen.Import.route) {
            ImportScreen(
                vpnViewModel = vpnViewModel,
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }

        composable(Screen.Settings.route) {
            SettingsScreen(
                vpnViewModel = vpnViewModel,
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }
    }
}
