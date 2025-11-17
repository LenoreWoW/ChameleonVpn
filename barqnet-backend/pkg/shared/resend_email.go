package shared

import (
	"fmt"
	"log"
	"strings"

	"github.com/resend/resend-go/v3"
)

// ResendEmailService implements EmailService using Resend
type ResendEmailService struct {
	client    *resend.Client
	from      string
	templates *EmailTemplates
	validator *EmailValidator
}

// NewResendEmailService creates a new Resend email service
func NewResendEmailService(apiKey, fromEmail string) (*ResendEmailService, error) {
	if apiKey == "" {
		return nil, fmt.Errorf("resend API key is required")
	}

	if fromEmail == "" {
		return nil, fmt.Errorf("from email address is required")
	}

	// Create Resend client
	client := resend.NewClient(apiKey)

	return &ResendEmailService{
		client:    client,
		from:      fromEmail,
		templates: DefaultEmailTemplates(),
		validator: &EmailValidator{},
	}, nil
}

// SendOTP sends a one-time password to the specified email address
func (s *ResendEmailService) SendOTP(email, code string) error {
	// Normalize email
	email = s.validator.NormalizeEmail(email)

	// Validate email
	if err := s.validator.ValidateEmail(email); err != nil {
		return fmt.Errorf("invalid email: %w", err)
	}

	// Validate OTP code
	if code == "" || len(code) != 6 {
		return fmt.Errorf("invalid OTP code: must be 6 digits")
	}

	// Replace template placeholders
	htmlBody := strings.ReplaceAll(s.templates.OTPHTML, "{{CODE}}", code)
	textBody := strings.ReplaceAll(s.templates.OTPText, "{{CODE}}", code)

	// Create email request
	params := &resend.SendEmailRequest{
		From:    s.from,
		To:      []string{email},
		Subject: s.templates.OTPSubject,
		Html:    htmlBody,
		Text:    textBody,
		Tags: []resend.Tag{
			{Name: "type", Value: "otp"},
		},
	}

	// Send email via Resend
	sent, err := s.client.Emails.Send(params)
	if err != nil {
		log.Printf("[EMAIL] Failed to send OTP to %s: %v", email, err)
		return fmt.Errorf("failed to send email: %w", err)
	}

	log.Printf("[EMAIL] OTP sent to %s (ID: %s)", email, sent.Id)
	return nil
}

// SendMagicLink sends a magic link for passwordless authentication
// (Future implementation for Option 2/3)
func (s *ResendEmailService) SendMagicLink(email, token, link string) error {
	// Normalize email
	email = s.validator.NormalizeEmail(email)

	// Validate email
	if err := s.validator.ValidateEmail(email); err != nil {
		return fmt.Errorf("invalid email: %w", err)
	}

	// Validate token and link
	if token == "" || link == "" {
		return fmt.Errorf("invalid magic link: token and link are required")
	}

	// Create magic link email (placeholder template for future)
	htmlBody := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>BarqNet Magic Link</title>
</head>
<body style="font-family: Arial, sans-serif;">
    <h1>Login to BarqNet</h1>
    <p>Click the button below to login to your BarqNet VPN account:</p>
    <a href="%s" style="display: inline-block; background-color: #667eea; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0;">
        Login to BarqNet
    </a>
    <p>Or copy this link: <code>%s</code></p>
    <p><strong>This link expires in 10 minutes.</strong></p>
    <p>If you didn't request this, please ignore this email.</p>
</body>
</html>`, link, link)

	textBody := fmt.Sprintf(`BarqNet VPN - Magic Link Login

Click this link to login: %s

This link expires in 10 minutes.

If you didn't request this, please ignore this email.`, link)

	params := &resend.SendEmailRequest{
		From:    s.from,
		To:      []string{email},
		Subject: "Login to BarqNet VPN",
		Html:    htmlBody,
		Text:    textBody,
		Tags: []resend.Tag{
			{Name: "type", Value: "magic-link"},
		},
	}

	// Send email via Resend
	sent, err := s.client.Emails.Send(params)
	if err != nil {
		log.Printf("[EMAIL] Failed to send magic link to %s: %v", email, err)
		return fmt.Errorf("failed to send email: %w", err)
	}

	log.Printf("[EMAIL] Magic link sent to %s (ID: %s)", email, sent.Id)
	return nil
}

// SendWelcome sends a welcome email to new users
func (s *ResendEmailService) SendWelcome(email, username string) error {
	// Normalize email
	email = s.validator.NormalizeEmail(email)

	// Validate email
	if err := s.validator.ValidateEmail(email); err != nil {
		return fmt.Errorf("invalid email: %w", err)
	}

	// Default username if empty
	if username == "" {
		username = "there"
	}

	// Replace template placeholders
	htmlBody := strings.ReplaceAll(s.templates.WelcomeHTML, "{{USERNAME}}", username)
	textBody := strings.ReplaceAll(s.templates.WelcomeText, "{{USERNAME}}", username)

	params := &resend.SendEmailRequest{
		From:    s.from,
		To:      []string{email},
		Subject: "Welcome to BarqNet VPN!",
		Html:    htmlBody,
		Text:    textBody,
		Tags: []resend.Tag{
			{Name: "type", Value: "welcome"},
		},
	}

	// Send email via Resend
	sent, err := s.client.Emails.Send(params)
	if err != nil {
		log.Printf("[EMAIL] Failed to send welcome email to %s: %v", email, err)
		return fmt.Errorf("failed to send email: %w", err)
	}

	log.Printf("[EMAIL] Welcome email sent to %s (ID: %s)", email, sent.Id)
	return nil
}

// LocalEmailService is a development implementation that logs emails to console
// Use this for local development and testing without actual email delivery
type LocalEmailService struct {
	validator *EmailValidator
}

// NewLocalEmailService creates a new local email service (for development)
func NewLocalEmailService() *LocalEmailService {
	return &LocalEmailService{
		validator: &EmailValidator{},
	}
}

// SendOTP logs OTP to console (development only)
func (s *LocalEmailService) SendOTP(email, code string) error {
	email = s.validator.NormalizeEmail(email)

	if err := s.validator.ValidateEmail(email); err != nil {
		return err
	}

	log.Printf("\n" + strings.Repeat("=", 60))
	log.Printf("[LOCAL EMAIL] OTP for %s", email)
	log.Printf(strings.Repeat("=", 60))
	log.Printf("Verification Code: %s", code)
	log.Printf("Expires in: 10 minutes")
	log.Printf(strings.Repeat("=", 60) + "\n")

	return nil
}

// SendMagicLink logs magic link to console (development only)
func (s *LocalEmailService) SendMagicLink(email, token, link string) error {
	email = s.validator.NormalizeEmail(email)

	if err := s.validator.ValidateEmail(email); err != nil {
		return err
	}

	log.Printf("\n" + strings.Repeat("=", 60))
	log.Printf("[LOCAL EMAIL] Magic Link for %s", email)
	log.Printf(strings.Repeat("=", 60))
	log.Printf("Token: %s", token)
	log.Printf("Link: %s", link)
	log.Printf("Expires in: 10 minutes")
	log.Printf(strings.Repeat("=", 60) + "\n")

	return nil
}

// SendWelcome logs welcome email to console (development only)
func (s *LocalEmailService) SendWelcome(email, username string) error {
	email = s.validator.NormalizeEmail(email)

	if err := s.validator.ValidateEmail(email); err != nil {
		return err
	}

	log.Printf("\n" + strings.Repeat("=", 60))
	log.Printf("[LOCAL EMAIL] Welcome Email for %s", email)
	log.Printf(strings.Repeat("=", 60))
	log.Printf("Welcome, %s!", username)
	log.Printf("Thank you for joining BarqNet VPN")
	log.Printf(strings.Repeat("=", 60) + "\n")

	return nil
}
