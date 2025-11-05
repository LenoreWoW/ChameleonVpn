import Store from 'electron-store';
import { CertificatePinning } from '../vpn/certificate-pinning';
import * as https from 'https';

interface User {
  id: string;
  phoneNumber: string;
}

interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenIssuedAt: number;
}

interface AuthSession {
  phoneNumber: string;
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
    this.apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:8080';

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
    if (this.isAuthenticated()) {
      this.scheduleTokenRefresh();
    }
  }

  /**
   * Initialize certificate pins for production API server
   *
   * DISABLED FOR MVP: Certificate pinning requires actual production certificates
   * Enable this after obtaining real certificate hashes from production API server
   *
   * To generate pins: openssl s_client -connect api.chameleonvpn.com:443 < /dev/null | \
   *   openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | \
   *   openssl dgst -sha256 -binary | base64
   */
  private initializeCertificatePins(): void {
    // DISABLED FOR MVP: Certificate pinning requires real production certificates
    // TODO: Enable after obtaining actual certificate pins from production server
    console.log('[AUTH] Certificate pinning DISABLED (MVP - no production certs yet)');

    // Uncomment and update when ready for production:
    /*
    try {
      const apiUrl = new URL(this.apiBaseUrl);

      if (process.env.NODE_ENV === 'production' && apiUrl.protocol === 'https:') {
        const productionPins = [
          'sha256/REAL_PRIMARY_CERTIFICATE_PIN_HERE',
          'sha256/REAL_BACKUP_CERTIFICATE_PIN_HERE'
        ];

        this.certificatePinning.addPin(apiUrl.hostname, productionPins);
        console.log(`[AUTH] Certificate pinning enabled for ${apiUrl.hostname}`);
      }
    } catch (error) {
      console.error('[AUTH] Failed to initialize certificate pinning:', error);
    }
    */
  }

  private getAuthHeaders(): HeadersInit {
    const tokens = this.getTokens();
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

  private getTokens(): AuthTokens | null {
    return this.store.get('tokens', null) as AuthTokens | null;
  }

  private saveTokens(tokens: AuthTokens): void {
    this.store.set('tokens', {
      ...tokens,
      tokenIssuedAt: Date.now()
    });
    this.scheduleTokenRefresh();
  }

  private clearTokens(): void {
    this.store.delete('tokens');
    this.store.delete('currentUser');
    if (this.tokenRefreshTimer) {
      clearTimeout(this.tokenRefreshTimer);
      this.tokenRefreshTimer = null;
    }
  }

  private scheduleTokenRefresh(): void {
    const tokens = this.getTokens();
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
      const tokens = this.getTokens();
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
      const response = await this.secureFetch(`${this.apiBaseUrl}${endpoint}`, {
        ...options,
        headers: this.getAuthHeaders()
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

  async sendOTP(phoneNumber: string): Promise<{ success: boolean; error?: string }> {
    try {
      // DEVELOPMENT MODE: Generate and log OTP to console
      if (process.env.NODE_ENV !== 'production') {
        const devOtpCode = Math.floor(100000 + Math.random() * 900000).toString();

        console.log('\n╔═══════════════════════════════════════════════════════╗');
        console.log('║         🔐 DEVELOPMENT MODE - OTP CODE              ║');
        console.log('╠═══════════════════════════════════════════════════════╣');
        console.log(`║  Phone: ${phoneNumber.padEnd(42)} ║`);
        console.log(`║  Code:  ${devOtpCode.padEnd(42)} ║`);
        console.log('╚═══════════════════════════════════════════════════════╝\n');

        // Store in session for verification
        this.sessions.set(phoneNumber, {
          phoneNumber,
          sessionId: 'dev-session-' + Date.now(),
          devOtpCode
        });

        return { success: true };
      }

      // PRODUCTION MODE: Call backend API
      const result = await this.apiCall('/v1/auth/otp/send', {
        method: 'POST',
        body: JSON.stringify({
          phoneNumber,
          countryCode: 'US' // TODO: Extract from phone number or make configurable
        })
      });

      if (!result.success) {
        return { success: false, error: result.error };
      }

      // Save session ID for verification
      if (result.data?.sessionId) {
        this.sessions.set(phoneNumber, {
          phoneNumber,
          sessionId: result.data.sessionId
        });
      }

      return { success: true };
    } catch (error) {
      console.error('[AUTH] Failed to send OTP:', error);
      return { success: false, error: (error as Error).message };
    }
  }

  async verifyOTP(phoneNumber: string, code: string): Promise<{ success: boolean; error?: string }> {
    try {
      const session = this.sessions.get(phoneNumber);

      // DEVELOPMENT MODE: Verify against stored OTP code
      if (process.env.NODE_ENV !== 'production' && session?.devOtpCode) {
        if (code === session.devOtpCode) {
          console.log('[AUTH-DEV] ✅ OTP verified successfully');

          // Generate development verification token
          const verificationToken = 'dev-token-' + Date.now();
          this.sessions.set(phoneNumber, {
            ...session,
            verificationToken
          });

          return { success: true };
        } else {
          console.log('[AUTH-DEV] ❌ OTP verification failed');
          console.log(`[AUTH-DEV] Expected: ${session.devOtpCode}, Got: ${code}`);
          return { success: false, error: 'Invalid OTP code' };
        }
      }

      // PRODUCTION MODE: Call backend API
      const result = await this.apiCall('/v1/auth/otp/verify', {
        method: 'POST',
        body: JSON.stringify({
          phoneNumber,
          otp: code,
          sessionId: session?.sessionId
        })
      });

      if (!result.success) {
        return { success: false, error: result.error };
      }

      // Save verification token for account creation
      if (result.data?.verificationToken) {
        this.sessions.set(phoneNumber, {
          phoneNumber,
          sessionId: session?.sessionId,
          verificationToken: result.data.verificationToken
        });
      }

      return { success: true };
    } catch (error) {
      console.error('[AUTH] Failed to verify OTP:', error);
      return { success: false, error: (error as Error).message };
    }
  }

  async createAccount(phoneNumber: string, password: string, otpCode: string): Promise<{ success: boolean; error?: string }> {
    try {
      // Validate password strength
      if (password.length < 8) {
        return { success: false, error: 'Password must be at least 8 characters' };
      }

      // DEVELOPMENT MODE: Create mock account
      if (process.env.NODE_ENV !== 'production') {
        // Verify OTP in dev mode
        const session = this.sessions.get(phoneNumber);
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
          phoneNumber: phoneNumber
        });

        // Clean up session
        this.sessions.delete(phoneNumber);

        console.log('[AUTH-DEV] Account created successfully');
        return { success: true };
      }

      // PRODUCTION MODE: Call backend API with OTP code
      const result = await this.apiCall('/v1/auth/register', {
        method: 'POST',
        body: JSON.stringify({
          phone_number: phoneNumber,
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
          phoneNumber: result.data.user?.phoneNumber || phoneNumber
        });
      }

      // Clean up session
      this.sessions.delete(phoneNumber);

      return { success: true };
    } catch (error) {
      console.error('[AUTH] Failed to create account:', error);
      return { success: false, error: (error as Error).message };
    }
  }

  async login(phoneNumber: string, password: string): Promise<{ success: boolean; error?: string }> {
    try {
      // DEVELOPMENT MODE: Use stored dev user
      if (process.env.NODE_ENV !== 'production') {
        const storedUser = this.store.get('currentUser') as User;

        if (storedUser?.phoneNumber === phoneNumber) {
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
          phone_number: phoneNumber,
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
          phoneNumber: result.data.user?.phoneNumber || phoneNumber
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

  isAuthenticated(): boolean {
    const tokens = this.getTokens();
    if (!tokens) {
      return false;
    }

    // Check if token is expired
    const expiresAt = tokens.tokenIssuedAt + (tokens.expiresIn * 1000);
    if (Date.now() >= expiresAt) {
      // Token expired, try to refresh
      this.refreshAccessToken();
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
