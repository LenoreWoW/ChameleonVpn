package shared

import (
	"fmt"
	"regexp"
	"strings"
)

// EmailService defines the interface for sending emails
// Implementations can use different providers (Resend, SendGrid, AWS SES, etc.)
type EmailService interface {
	// SendOTP sends a one-time password to the specified email address
	SendOTP(email, code string) error

	// SendMagicLink sends a magic link for passwordless authentication
	// (Future implementation for Option 2/3)
	SendMagicLink(email, token, link string) error

	// SendWelcome sends a welcome email to new users
	SendWelcome(email, username string) error
}

// EmailValidator provides email validation utilities
type EmailValidator struct{}

// ValidateEmail checks if an email address is valid
func (v *EmailValidator) ValidateEmail(email string) error {
	// Trim whitespace
	email = strings.TrimSpace(email)

	// Check if empty
	if email == "" {
		return fmt.Errorf("email address cannot be empty")
	}

	// Check length
	if len(email) > 255 {
		return fmt.Errorf("email address too long (max 255 characters)")
	}

	// RFC 5322 compliant email regex (simplified)
	// This regex matches most common email formats
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9.!#$%&'*+/=?^_` + "`" + `{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$`)

	if !emailRegex.MatchString(email) {
		return fmt.Errorf("invalid email format")
	}

	// Check for common typos
	// commonDomains := []string{"gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "icloud.com"}
	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return fmt.Errorf("invalid email format")
	}

	domain := strings.ToLower(parts[1])

	// Check for common domain typos (optional - can be removed if too strict)
	if strings.Contains(domain, "gmial") || strings.Contains(domain, "gmai") {
		return fmt.Errorf("did you mean gmail.com?")
	}

	// All validation passed
	return nil
}

// NormalizeEmail normalizes an email address for storage
// Converts to lowercase and trims whitespace
func (v *EmailValidator) NormalizeEmail(email string) string {
	email = strings.TrimSpace(email)
	email = strings.ToLower(email)
	return email
}

// EmailTemplates contains HTML and text templates for emails
type EmailTemplates struct {
	OTPSubject  string
	OTPHTML     string
	OTPText     string
	WelcomeHTML string
	WelcomeText string
}

// DefaultEmailTemplates returns default email templates
func DefaultEmailTemplates() *EmailTemplates {
	return &EmailTemplates{
		OTPSubject: "Your BarqNet Verification Code",

		OTPHTML: `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BarqNet Verification Code</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 28px;">BarqNet</h1>
    </div>
    <div style="background-color: #ffffff; padding: 40px; border-radius: 0 0 10px 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
        <h2 style="color: #667eea; margin-top: 0;">Your Verification Code</h2>
        <p style="font-size: 16px;">Hello,</p>
        <p style="font-size: 16px;">Here's your verification code to complete your BarqNet VPN login:</p>
        <div style="background-color: #f7f7f7; border: 2px dashed #667eea; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0;">
            <p style="font-size: 14px; color: #666; margin: 0 0 10px 0;">Your verification code is:</p>
            <h1 style="font-size: 48px; color: #667eea; margin: 0; letter-spacing: 8px; font-family: 'Courier New', monospace;">{{CODE}}</h1>
        </div>
        <p style="font-size: 14px; color: #666;">
            <strong>Important:</strong> This code will expire in <strong>10 minutes</strong>.
            If you didn't request this code, please ignore this email.
        </p>
        <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 30px 0;">
        <p style="font-size: 12px; color: #999; text-align: center;">
            This is an automated message from BarqNet VPN. Please do not reply to this email.
        </p>
    </div>
</body>
</html>`,

		OTPText: `BarqNet VPN - Verification Code

Hello,

Here's your verification code to complete your BarqNet VPN login:

Verification Code: {{CODE}}

This code will expire in 10 minutes.

If you didn't request this code, please ignore this email.

---
This is an automated message from BarqNet VPN.`,

		WelcomeHTML: `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Welcome to BarqNet</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #667eea;">Welcome to BarqNet VPN!</h1>
        <p>Hi {{USERNAME}},</p>
        <p>Thank you for joining BarqNet VPN. Your account has been successfully created.</p>
        <p>You can now enjoy secure, private internet access on all your devices.</p>
        <p>If you have any questions, please don't hesitate to contact our support team.</p>
        <p>Best regards,<br>The BarqNet Team</p>
    </div>
</body>
</html>`,

		WelcomeText: `Welcome to BarqNet VPN!

Hi {{USERNAME}},

Thank you for joining BarqNet VPN. Your account has been successfully created.

You can now enjoy secure, private internet access on all your devices.

If you have any questions, please don't hesitate to contact our support team.

Best regards,
The BarqNet Team`,
	}
}
