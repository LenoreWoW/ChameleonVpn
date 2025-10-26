package com.barqnet.android.ui.screens.onboarding

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.barqnet.android.ui.theme.*

@Composable
fun OTPVerificationScreen(
    phoneNumber: String,
    onVerify: (String) -> Unit,
    onResend: () -> Unit
) {
    var otpCode by remember { mutableStateOf(List(6) { "" }) }
    val focusRequesters = remember { List(6) { FocusRequester() } }
    var isLoading by remember { mutableStateOf(false) }
    var showError by remember { mutableStateOf(false) }

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

    LaunchedEffect(Unit) {
        focusRequesters[0].requestFocus()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(DarkBg, DarkBgSecondary, DarkBgTertiary)
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
            Text(
                text = "🔐",
                style = MaterialTheme.typography.displayLarge,
                modifier = Modifier.offset(y = floatOffset.dp)
            )

            Spacer(modifier = Modifier.height(24.dp))

            Text(
                text = "Verify Your Number",
                style = MaterialTheme.typography.headlineLarge,
                color = CyanBlue,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "We've sent a 6-digit code to $phoneNumber",
                style = MaterialTheme.typography.bodyLarge,
                color = Color.White.copy(alpha = 0.6f),
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(40.dp))

            // OTP Input
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                otpCode.forEachIndexed { index, digit ->
                    BasicTextField(
                        value = digit,
                        onValueChange = { newValue ->
                            if (newValue.length <= 1 && newValue.all { it.isDigit() }) {
                                val newOtp = otpCode.toMutableList()
                                newOtp[index] = newValue
                                otpCode = newOtp

                                // Auto-focus next field
                                if (newValue.isNotEmpty() && index < 5) {
                                    focusRequesters[index + 1].requestFocus()
                                }

                                // Auto-verify when all filled
                                if (index == 5 && newValue.isNotEmpty()) {
                                    val code = otpCode.joinToString("")
                                    if (code.length == 6) {
                                        isLoading = true
                                        onVerify(code)
                                    }
                                }
                            } else if (newValue.isEmpty() && index > 0) {
                                focusRequesters[index - 1].requestFocus()
                            }
                        },
                        modifier = Modifier
                            .size(56.dp)
                            .background(
                                color = Color.Black.copy(alpha = 0.4f),
                                shape = RoundedCornerShape(12.dp)
                            )
                            .border(
                                width = 2.dp,
                                color = if (digit.isNotEmpty()) CyanBlue else CyanBlue.copy(alpha = 0.3f),
                                shape = RoundedCornerShape(12.dp)
                            )
                            .focusRequester(focusRequesters[index]),
                        textStyle = TextStyle(
                            color = Color.White,
                            fontSize = 24.sp,
                            textAlign = TextAlign.Center
                        ),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        singleLine = true,
                        decorationBox = { innerTextField ->
                            Box(
                                contentAlignment = Alignment.Center,
                                modifier = Modifier.fillMaxSize()
                            ) {
                                innerTextField()
                            }
                        }
                    )
                }
            }

            if (showError) {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "Invalid code. Please try again.",
                    color = Red,
                    style = MaterialTheme.typography.bodyMedium
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            Button(
                onClick = {
                    val code = otpCode.joinToString("")
                    if (code.length == 6) {
                        isLoading = true
                        onVerify(code)
                    } else {
                        showError = true
                    }
                },
                enabled = !isLoading,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
                shape = RoundedCornerShape(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.horizontalGradient(listOf(CyanBlue, DeepBlue)),
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
                        Text("VERIFY CODE", style = MaterialTheme.typography.labelLarge)
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            TextButton(onClick = onResend) {
                Text(
                    "Didn't receive code? Resend",
                    color = CyanBlue,
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}
