import Store from 'electron-store';

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
}

// API-integrated auth service
// Connects to backend API for authentication
class AuthService {
  private store: Store;
  private sessions: Map<string, AuthSession>;
  private apiBaseUrl: string;
  private tokenRefreshTimer: NodeJS.Timeout | null = null;

  constructor() {
    this.store = new Store({ name: 'auth' });
    this.sessions = new Map();

    // API base URL from environment variable or default to localhost
    this.apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:8080';

    // Start token refresh timer if user is authenticated
    if (this.isAuthenticated()) {
      this.scheduleTokenRefresh();
    }
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
          refreshToken: tokens.refreshToken
        })
      });

      if (!response.ok) {
        // Refresh token invalid, clear session
        this.clearTokens();
        return false;
      }

      const data = await response.json();

      if (data.success && data.accessToken) {
        this.saveTokens({
          accessToken: data.accessToken,
          refreshToken: tokens.refreshToken,
          expiresIn: data.expiresIn,
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

  private async apiCall<T = any>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<{ success: boolean; data?: T; error?: string }> {
    try {
      const response = await fetch(`${this.apiBaseUrl}${endpoint}`, {
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

  async createAccount(phoneNumber: string, password: string): Promise<{ success: boolean; error?: string }> {
    try {
      // Validate password strength
      if (password.length < 8) {
        return { success: false, error: 'Password must be at least 8 characters' };
      }

      const session = this.sessions.get(phoneNumber);
      if (!session?.verificationToken) {
        return { success: false, error: 'Phone number not verified. Please verify OTP first.' };
      }

      const result = await this.apiCall('/v1/auth/register', {
        method: 'POST',
        body: JSON.stringify({
          phoneNumber,
          password,
          verificationToken: session.verificationToken
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
      const result = await this.apiCall('/v1/auth/login', {
        method: 'POST',
        body: JSON.stringify({
          phoneNumber,
          password
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
