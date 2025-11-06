package com.barqnet.android.ui.screens.onboarding

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.barqnet.android.ui.theme.*

@OptIn(ExperimentalAnimationApi::class)
@Composable
fun PhoneNumberScreen(
    onContinue: (String) -> Unit,
    onLoginClick: () -> Unit
) {
    var phoneNumber by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }

    val infiniteTransition = rememberInfiniteTransition(label = "float")
    val floatOffset by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = -10f,
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = EaseInOutQuad),
            repeatMode = RepeatMode.Reverse
        ),
        label = "float"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        DarkBg,
                        DarkBgSecondary,
                        DarkBgTertiary
                    )
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Floating Icon
            Text(
                text = "📱",
                style = MaterialTheme.typography.displayLarge,
                modifier = Modifier.offset(y = floatOffset.dp)
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Title with gradient
            Text(
                text = "Welcome to BarqNet",
                style = MaterialTheme.typography.headlineLarge,
                color = CyanBlue,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "Enter your phone number to get started with secure, private browsing",
                style = MaterialTheme.typography.bodyLarge,
                color = Color.White.copy(alpha = 0.6f),
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(40.dp))

            // Phone Number Input
            OutlinedTextField(
                value = phoneNumber,
                onValueChange = { phoneNumber = it },
                label = { Text("PHONE NUMBER", style = MaterialTheme.typography.labelMedium) },
                placeholder = { Text("+1 (555) 123-4567", color = Color.White.copy(alpha = 0.3f)) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = CyanBlue,
                    unfocusedBorderColor = CyanBlue.copy(alpha = 0.2f),
                    focusedLabelColor = CyanBlue,
                    unfocusedLabelColor = Color.White.copy(alpha = 0.6f),
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                ),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Continue Button with gradient
            Button(
                onClick = {
                    if (phoneNumber.isNotBlank()) {
                        isLoading = true
                        onContinue(phoneNumber)
                    }
                },
                enabled = phoneNumber.isNotBlank() && !isLoading,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Transparent,
                    disabledContainerColor = Color.Gray
                ),
                shape = RoundedCornerShape(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.horizontalGradient(
                                colors = listOf(CyanBlue, DeepBlue)
                            ),
                            shape = RoundedCornerShape(12.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(
                            color = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                    } else {
                        Text(
                            text = "CONTINUE",
                            style = MaterialTheme.typography.labelLarge,
                            color = Color.White
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Login Link
            TextButton(onClick = onLoginClick) {
                Text(
                    text = "Already have an account? Sign In",
                    color = CyanBlue,
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}
