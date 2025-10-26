package com.barqnet.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Blue Theme Colors
val CyanBlue = Color(0xFF00D4FF)
val DeepBlue = Color(0xFF0088FF)
val MediumBlue = Color(0xFF3399FF)

val DarkBg = Color(0xFF0A0E27)
val DarkBgSecondary = Color(0xFF1A2332)
val DarkBgTertiary = Color(0xFF0F1729)

val Green = Color(0xFF10B981)
val GreenDark = Color(0xFF059669)
val Red = Color(0xFFEF4444)
val RedDark = Color(0xFFDC2626)
val Orange = Color(0xFFF59E0B)
val OrangeDark = Color(0xFFD97706)

val GrayLight = Color(0xFF64748B)
val GrayDark = Color(0xFF475569)

private val DarkColorScheme = darkColorScheme(
    primary = CyanBlue,
    secondary = DeepBlue,
    tertiary = MediumBlue,
    background = DarkBg,
    surface = DarkBgSecondary,
    onPrimary = Color.White,
    onSecondary = Color.White,
    onTertiary = Color.White,
    onBackground = Color.White,
    onSurface = Color.White,
    error = Red,
    onError = Color.White
)

@Composable
fun BarqNetTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography = Typography,
        content = content
    )
}
