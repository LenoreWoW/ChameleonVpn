import Store from 'electron-store';
import { CertificatePinning } from '../vpn/certificate-pinning';
import * as https from 'https';
import * as keytar from 'keytar';

interface User {
  id: string;
  email: string;
}

interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenIssuedAt: number;
}

interface AuthSession {
  email: string;
  sessionId?: string;
  verificationToken?: string;
  devOtpCode?: string; // Development mode OTP code
}

// API-integrated auth service with certificate pinning
// Connects to backend API for authentication
class AuthService {
  private store: Store;
  private sessions: Map<string, AuthSession>;
  private apiBaseUrl: string;
  private tokenRefreshTimer: NodeJS.Timeout | null = null;
  private certificatePinning: CertificatePinning;

  constructor() {
    this.store = new Store({ name: 'auth' });
    this.sessions = new Map();

    // API base URL from environment variable or default to localhost
    this.apiBaseUrl = process.env.API_BASE_URL || 'http://127.0.0.1:8085';

    // Initialize certificate pinning with production pins
    this.certificatePinning = new CertificatePinning();
    this.initializeCertificatePins();

    // CRITICAL SECURITY: Enforce HTTPS in production
    if (process.env.NODE_ENV === 'production') {
      try {
        const url = new URL(this.apiBaseUrl);
        if (url.protocol !== 'https:') {
          throw new Error('Production authentication MUST use HTTPS');
        }
      } catch (error) {
        console.error('[AUTH] FATAL: Insecure API URL in production:', this.apiBaseUrl);
        throw error;
      }
    }

    // Start token refresh timer if user is authenticated
    // Note: isAuthenticated() is async, so we check in initialization
    this.isAuthenticated().then((authenticated) => {
      if (authenticated) {
        this.scheduleTokenRefresh();
      }
    });
  }

  /**
   * Initialize certificate pins for production API server
   *
   * Certificate pinning protects against MITM attacks by validating the server's
   * certificate against known public key hashes (pins).
   *
   * Pinning Strategy:
   * - Primary Pin: Your specific leaf certificate (extracted from your API server)
   * - Backup Pins: Intermediate CA and Root CA pins (for rotation flexibility)
   *
   * To extract your primary pin:
   *   ./scripts/extract-cert-pins.sh --server api.example.com
   *
   * Or manually:
   *   openssl s_client -connect api.example.com:443 < /dev/null 2>/dev/null | \
   *     openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | \
   *     openssl dgst -sha256 -binary | base64
   */
  private initializeCertificatePins(): void {
    try {
      const apiUrl = new URL(this.apiBaseUrl);

      // Only enable pinning for HTTPS connections
      if (apiUrl.protocol !== 'https:') {
        console.log('[AUTH] Certificate pinning skipped (not using HTTPS)');
        return;
      }

      // Check if certificate pinning is enabled via environment variable
      const certPinningEnabled = process.env.CERT_PINNING_ENABLED !== 'false';

      if (!certPinningEnabled) {
        console.log('[AUTH] Certificate pinning DISABLED via CERT_PINNING_ENABLED=false');
        console.warn('[AUTH] WARNING: Running without certificate pinning is insecure in production');
        return;
      }

      // Get primary and backup pins from environment variables
      const primaryPin = process.env.CERT_PIN_PRIMARY;
      const backupPin = process.env.CERT_PIN_BACKUP;

      // Build list of certificate pins
      const pins: string[] = [];

      if (primaryPin) {
        pins.push(primaryPin);
        console.log('[AUTH] Primary certificate pin configured');
      }

      if (backupPin) {
        pins.push(backupPin);
        console.log('[AUTH] Backup certificate pin configured');
      }

      // If no pins configured but in production, use well-known CA pins as fallback
      // This provides some protection while allowing common CAs
      if (pins.length === 0 && process.env.NODE_ENV === 'production') {
        console.warn('[AUTH] WARNING: No certificate pins configured!');
        console.warn('[AUTH] Using fallback pins for common CAs (Let\'s Encrypt, DigiCert)');
        console.warn('[AUTH] For maximum security, configure CERT_PIN_PRIMARY and CERT_PIN_BACKUP');

        // Let's Encrypt intermediate certificates (most common for production)
        pins.push('sha256/jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0='); // Let's Encrypt R3
        pins.push('sha256/VQYeFC8zhEDLrcyYYWBvPTfM5VWhTzfhEHQ9L5wBaB0='); // Let's Encrypt E1
        pins.push('sha256/C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M='); // ISRG Root X1

        // DigiCert intermediate certificates (alternative)
        pins.push('sha256/i7WTqTvh0OioIruIfFR4kMPnBqrS2rdiVPl/s2uC/CY='); // DigiCert Global Root G2
        pins.push('sha256/RQeZkB42znUfsDIIFWWHm0nizHcVpsJNL8Qgg6iEvto='); // DigiCert TLS RSA SHA256 2020 CA1
      }

      // Add pins if we have any
      if (pins.length > 0) {
        this.certificatePinning.addPin(apiUrl.hostname, pins);
        console.log(`[AUTH] ✓ Certificate pinning enabled for ${apiUrl.hostname}`);
        console.log(`[AUTH]   - Configured ${pins.length} certificate pin(s)`);
        console.log(`[AUTH]   - HTTPS connections will be validated against known pins`);

        if (!primaryPin && process.env.NODE_ENV === 'production') {
          console.warn('[AUTH] ⚠ Using fallback CA pins only - configure specific pins for maximum security');
        }
      } else {
        console.log('[AUTH] Certificate pinning not configured (development mode)');
        if (process.env.NODE_ENV !== 'production') {
          console.log('[AUTH] To enable, set CERT_PIN_PRIMARY and CERT_PIN_BACKUP in .env');
        }
      }
    } catch (error) {
      console.error('[AUTH] Failed to initialize certificate pinning:', error);
      console.error('[AUTH] Continuing without certificate pinning - connections may be vulnerable');
    }
  }

  private async getAuthHeaders(): Promise<HeadersInit> {
    const tokens = await this.getTokens();
    if (tokens?.accessToken) {
      return {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${tokens.accessToken}`
      };
    }
    return {
      'Content-Type': 'application/json'
    };
  }

  private async getTokens(): Promise<AuthTokens | null> {
    try {
      // Use system keychain for secure token storage
      const tokensJson = await keytar.getPassword('barqnet', 'auth-tokens');
      if (!tokensJson) {
        return null;
      }
      return JSON.parse(tokensJson) as AuthTokens;
    } catch (error) {
      console.error('[AUTH] Failed to load tokens from keychain:', error);
      return null;
    }
  }

  private async saveTokens(tokens: AuthTokens): Promise<void> {
    try {
      // Store tokens in system keychain (encrypted by OS)
      const tokensWithTimestamp = {
        ...tokens,
        tokenIssuedAt: Date.now()
      };
      await keytar.setPassword('barqnet', 'auth-tokens', JSON.stringify(tokensWithTimestamp));
      this.scheduleTokenRefresh();
    } catch (error) {
      console.error('[AUTH] Failed to save tokens to keychain:', error);
      throw error;
    }
  }

  private async clearTokens(): Promise<void> {
    try {
      await keytar.deletePassword('barqnet', 'auth-tokens');
      this.store.delete('currentUser');
      if (this.tokenRefreshTimer) {
        clearTimeout(this.tokenRefreshTimer);
        this.tokenRefreshTimer = null;
      }
    } catch (error) {
      console.error('[AUTH] Failed to clear tokens from keychain:', error);
    }
  }

  private async scheduleTokenRefresh(): Promise<void> {
    const tokens = await this.getTokens();
    if (!tokens) return;

    // Clear existing timer
    if (this.tokenRefreshTimer) {
      clearTimeout(this.tokenRefreshTimer);
    }

    // Calculate when to refresh (5 minutes before expiry)
    const expiresInMs = tokens.expiresIn * 1000;
    const refreshAt = tokens.tokenIssuedAt + expiresInMs - (5 * 60 * 1000);
    const timeUntilRefresh = refreshAt - Date.now();

    if (timeUntilRefresh > 0) {
      this.tokenRefreshTimer = setTimeout(async () => {
        await this.refreshAccessToken();
      }, timeUntilRefresh);
    } else {
      // Token already expired or about to expire, refresh now
      this.refreshAccessToken();
    }
  }

  private async refreshAccessToken(): Promise<boolean> {
    try {
      const tokens = await this.getTokens();
      if (!tokens?.refreshToken) {
        return false;
      }

      const response = await fetch(`${this.apiBaseUrl}/v1/auth/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          token: tokens.refreshToken // Backend expects "token" field
        })
      });

      if (!response.ok) {
        // Refresh token invalid, clear session
        this.clearTokens();
        return false;
      }

      const data = await response.json();

      // Backend returns tokens in data object
      if (data.success && data.data?.accessToken && data.data?.refreshToken) {
        this.saveTokens({
          accessToken: data.data.accessToken,
          refreshToken: data.data.refreshToken,
          expiresIn: data.data.expiresIn || 86400,
          tokenIssuedAt: Date.now()
        });
        return true;
      }

      return false;
    } catch (error) {
      console.error('[AUTH] Failed to refresh token:', error);
      return false;
    }
  }

  /**
   * Secure fetch with certificate pinning support
   */
  private async secureFetch(url: string, options: RequestInit = {}): Promise<Response> {
    const apiUrl = new URL(url);

    // For HTTPS in production, use certificate pinning
    if (apiUrl.protocol === 'https:' && process.env.NODE_ENV === 'production') {
      return new Promise((resolve, reject) => {
        const tlsOptions = this.certificatePinning.getTLSOptions(apiUrl.hostname);
        const requestOptions = {
          hostname: apiUrl.hostname,
          port: apiUrl.port || 443,
          path: apiUrl.pathname + apiUrl.search,
          method: options.method || 'GET',
          headers: options.headers as Record<string, string>,
          ...tlsOptions
        };

        const req = https.request(requestOptions, (res) => {
          let data = '';
          res.on('data', (chunk) => { data += chunk; });
          res.on('end', () => {
            // Create Response-like object
            resolve({
              ok: res.statusCode! >= 200 && res.statusCode! < 300,
              status: res.statusCode!,
              statusText: res.statusMessage!,
              headers: res.headers as any,
              json: async () => JSON.parse(data),
              text: async () => data
            } as Response);
          });
        });

        req.on('error', reject);

        if (options.body) {
          req.write(options.body);
        }

        req.end();
      });
    }

    // For development or HTTP, use regular fetch
    return fetch(url, options);
  }

  private async apiCall<T = any>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<{ success: boolean; data?: T; error?: string }> {
    try {
      const headers = await this.getAuthHeaders();
      const response = await this.secureFetch(`${this.apiBaseUrl}${endpoint}`, {
        ...options,
        headers
      });

      const data = await response.json();

      if (!response.ok) {
        return {
          success: false,
          error: data.message || data.error || `HTTP ${response.status}`
        };
      }

      return {
        success: true,
        data
      };
    } catch (error) {
      // Network error - graceful degradation
      console.error(`[AUTH] API call failed for ${endpoint}:`, error);

      // Certificate pinning failure
      if (error instanceof Error && error.message.includes('Certificate pinning')) {
        return {
          success: false,
          error: 'Security error: Server certificate verification failed. Please contact support.'
        };
      }

      // Check if it's a network error
      if (error instanceof TypeError && error.message.includes('fetch')) {
        return {
          success: false,
          error: 'Backend server is not available. Please check your connection or try again later.'
        };
      }

      return {
        success: false,
        error: (error as Error).message || 'Unknown error occurred'
      };
    }
  }

  async sendOTP(email: string): Promise<{ success: boolean; error?: string }> {
    try {
      // DEVELOPMENT MODE: Generate and log OTP to console
      if (process.env.NODE_ENV !== 'production') {
        const devOtpCode = Math.floor(100000 + Math.random() * 900000).toString();

        console.log('\n╔═══════════════════════════════════════════════════════╗');
        console.log('║         🔐 DEVELOPMENT MODE - OTP CODE              ║');
        console.log('╠═══════════════════════════════════════════════════════╣');
        console.log(`║  Email: ${email.padEnd(42)} ║`);
        console.log(`║  Code:  ${devOtpCode.padEnd(42)} ║`);
        console.log('╚═══════════════════════════════════════════════════════╝\n');

        // Store in session for verification
        this.sessions.set(email, {
          email,
          sessionId: 'dev-session-' + Date.now(),
          devOtpCode
        });

        return { success: true };
      }

      // PRODUCTION MODE: Call backend API
      const result = await this.apiCall('/v1/auth/send-otp', {
        method: 'POST',
        body: JSON.stringify({
          email: email
        })
      });

      if (!result.success) {
        return { success: false, error: result.error };
      }

      // Save session ID for verification
      if (result.data?.sessionId) {
        this.sessions.set(email, {
          email,
          sessionId: result.data.sessionId
        });
      }

      return { success: true };
    } catch (error) {
      console.error('[AUTH] Failed to send OTP:', error);
      return { success: false, error: (error as Error).message };
    }
  }

  async verifyOTP(email: string, code: string): Promise<{ success: boolean; error?: string }> {
    try {
      const session = this.sessions.get(email);

      // DEVELOPMENT MODE: Verify against stored OTP code
      if (process.env.NODE_ENV !== 'production' && session?.devOtpCode) {
        if (code === session.devOtpCode) {
          console.log('[AUTH-DEV] ✅ OTP verified successfully');

          // Store verified OTP in session for use during registration
          this.sessions.set(email, {
            ...session,
            verificationToken: code // Store the actual OTP code
          });

          return { success: true };
        } else {
          console.log('[AUTH-DEV] ❌ OTP verification failed');
          console.log(`[AUTH-DEV] Expected: ${session.devOtpCode}, Got: ${code}`);
          return { success: false, error: 'Invalid OTP code' };
        }
      }

      // PRODUCTION MODE: Verify OTP with backend
      if (!code || code.length !== 6) {
        return { success: false, error: 'Invalid OTP format' };
      }

      const result = await this.apiCall('/v1/auth/verify-otp', {
        method: 'POST',
        body: JSON.stringify({
          email: email,
          otp: code,
          session_id: session?.sessionId
        })
      });

      if (!result.success) {
        return { success: false, error: result.error || 'Invalid OTP code' };
      }

      // Store verification token for registration
      this.sessions.set(email, {
        email,
        sessionId: session?.sessionId,
        verificationToken: result.data?.verification_token || code
      });

      console.log('[AUTH] ✅ OTP verified successfully');
      return { success: true };
    } catch (error) {
      console.error('[AUTH] Failed to verify OTP:', error);
      return { success: false, error: (error as Error).message };
    }
  }

  async createAccount(email: string, password: string, otpCode: string): Promise<{ success: boolean; error?: string }> {
    try {
      // Validate password strength
      if (password.length < 8) {
        return { success: false, error: 'Password must be at least 8 characters' };
      }

      // DEVELOPMENT MODE: Create mock account
      if (process.env.NODE_ENV !== 'production') {
        // Verify OTP in dev mode
        const session = this.sessions.get(email);
        if (!session?.devOtpCode || session.devOtpCode !== otpCode) {
          return { success: false, error: 'Invalid OTP code' };
        }

        console.log('[AUTH-DEV] ✅ Creating development account');

        // Generate development tokens
        const devAccessToken = 'dev-access-token-' + Date.now();
        const devRefreshToken = 'dev-refresh-token-' + Date.now();

        this.saveTokens({
          accessToken: devAccessToken,
          refreshToken: devRefreshToken,
          expiresIn: 3600,
          tokenIssuedAt: Date.now()
        });

        this.store.set('currentUser', {
          id: 'dev-user-' + Date.now(),
          email: email
        });

        // Clean up session
        this.sessions.delete(email);

        console.log('[AUTH-DEV] Account created successfully');
        return { success: true };
      }

      // PRODUCTION MODE: Call backend API with OTP code
      const result = await this.apiCall('/v1/auth/register', {
        method: 'POST',
        body: JSON.stringify({
          email: email,
          password: password,
          otp: otpCode
        })
      });

      if (!result.success) {
        return { success: false, error: result.error };
      }

      // Save tokens and user info
      if (result.data?.accessToken && result.data?.refreshToken) {
        this.saveTokens({
          accessToken: result.data.accessToken,
          refreshToken: result.data.refreshToken,
          expiresIn: result.data.expiresIn || 3600,
          tokenIssuedAt: Date.now()
        });

        this.store.set('currentUser', {
          id: result.data.user?.id,
          email: result.data.user?.email || email
        });
      }

      // Clean up session
      this.sessions.delete(email);

      return { success: true };
    } catch (error) {
      console.error('[AUTH] Failed to create account:', error);
      return { success: false, error: (error as Error).message };
    }
  }

  async login(email: string, password: string): Promise<{ success: boolean; error?: string }> {
    try {
      // DEVELOPMENT MODE: Use stored dev user
      if (process.env.NODE_ENV !== 'production') {
        const storedUser = this.store.get('currentUser') as User;

        if (storedUser?.email === email) {
          console.log('[AUTH-DEV] ✅ Login successful (dev mode - no password check)');

          // Generate new development tokens
          const devAccessToken = 'dev-access-token-' + Date.now();
          const devRefreshToken = 'dev-refresh-token-' + Date.now();

          this.saveTokens({
            accessToken: devAccessToken,
            refreshToken: devRefreshToken,
            expiresIn: 3600,
            tokenIssuedAt: Date.now()
          });

          return { success: true };
        } else {
          console.log('[AUTH-DEV] ❌ Login failed - User not found');
          return { success: false, error: 'Account not found. Please register first.' };
        }
      }

      // PRODUCTION MODE: Call backend API with snake_case fields
      const result = await this.apiCall('/v1/auth/login', {
        method: 'POST',
        body: JSON.stringify({
          email: email,
          password: password
        })
      });

      if (!result.success) {
        return { success: false, error: result.error };
      }

      // Save tokens and user info
      if (result.data?.accessToken && result.data?.refreshToken) {
        this.saveTokens({
          accessToken: result.data.accessToken,
          refreshToken: result.data.refreshToken,
          expiresIn: result.data.expiresIn || 3600,
          tokenIssuedAt: Date.now()
        });

        this.store.set('currentUser', {
          id: result.data.user?.id,
          email: result.data.user?.email || email
        });
      }

      return { success: true };
    } catch (error) {
      console.error('[AUTH] Login failed:', error);
      return { success: false, error: (error as Error).message };
    }
  }

  async logout(): Promise<void> {
    try {
      // Call backend logout endpoint
      await this.apiCall('/v1/auth/logout', {
        method: 'POST'
      });
    } catch (error) {
      console.error('[AUTH] Logout API call failed:', error);
      // Continue with local cleanup even if API call fails
    }

    // Clear local session
    this.clearTokens();
  }

  async isAuthenticated(): Promise<boolean> {
    const tokens = await this.getTokens();
    if (!tokens) {
      return false;
    }

    // Check if token is expired
    const expiresAt = tokens.tokenIssuedAt + (tokens.expiresIn * 1000);
    if (Date.now() >= expiresAt) {
      // Token expired
      // NOTE: Don't auto-refresh here (causes race condition)
      // Refresh is handled by automatic timer (scheduleTokenRefresh)
      // Or explicitly by API calls that get 401 responses
      return false;
    }

    return true;
  }

  getCurrentUser(): User | null {
    if (!this.isAuthenticated()) {
      return null;
    }

    return this.store.get('currentUser', null) as User | null;
  }

  getApiBaseUrl(): string {
    return this.apiBaseUrl;
  }
}

export const authService = new AuthService();
