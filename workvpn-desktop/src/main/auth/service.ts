import Store from 'electron-store';
import bcrypt from 'bcrypt';

const BCRYPT_ROUNDS = 12;

interface User {
  phoneNumber: string;
  passwordHash: string;
}

interface AuthSession {
  phoneNumber: string;
  otpCode?: string;
  otpExpiry?: number;
}

// Simple in-memory store for demo
// In production, this would connect to a backend API
class AuthService {
  private store: Store;
  private users: Map<string, User>;
  private sessions: Map<string, AuthSession>;
  private currentUser: string | null = null;

  constructor() {
    this.store = new Store({ name: 'auth' });
    this.users = new Map();
    this.sessions = new Map();

    // Load users from store
    const storedUsers = this.store.get('users', {}) as Record<string, User>;
    Object.entries(storedUsers).forEach(([phone, user]) => {
      this.users.set(phone, user);
    });

    // For demo: Start fresh each time (don't persist login session)
    // In production, uncomment the line below to persist sessions
    // this.currentUser = this.store.get('currentUser', null) as string | null;
    this.currentUser = null;
  }

  private saveUsers() {
    const usersObj: Record<string, User> = {};
    this.users.forEach((user, phone) => {
      usersObj[phone] = user;
    });
    this.store.set('users', usersObj);
  }

  async sendOTP(phoneNumber: string): Promise<{ success: boolean; error?: string }> {
    try {
      // Generate 6-digit OTP
      const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
      const otpExpiry = Date.now() + 10 * 60 * 1000; // 10 minutes

      this.sessions.set(phoneNumber, {
        phoneNumber,
        otpCode,
        otpExpiry
      });

      // BACKEND INTEGRATION: Your colleague's backend will handle SMS delivery
      // The backend should implement POST /auth/otp/send to:
      // - Generate OTP server-side
      // - Send SMS via Twilio/AWS SNS
      // - Return success to client
      // For development only:
      if (process.env.NODE_ENV !== 'production') {
        console.log(`[AUTH] DEBUG ONLY - OTP for ${phoneNumber}: ${otpCode}`);
      }

      return { success: true };
    } catch (error) {
      console.error('[AUTH] Failed to send OTP:', error);
      return { success: false, error: (error as Error).message };
    }
  }

  async verifyOTP(phoneNumber: string, code: string): Promise<{ success: boolean; error?: string }> {
    const session = this.sessions.get(phoneNumber);

    if (!session) {
      return { success: false, error: 'No OTP session found' };
    }

    if (!session.otpCode || !session.otpExpiry) {
      return { success: false, error: 'Invalid session' };
    }

    if (Date.now() > session.otpExpiry) {
      this.sessions.delete(phoneNumber);
      return { success: false, error: 'OTP expired' };
    }

    if (session.otpCode !== code) {
      return { success: false, error: 'Invalid OTP code' };
    }

    // OTP verified successfully
    return { success: true };
  }

  async createAccount(phoneNumber: string, password: string): Promise<{ success: boolean; error?: string }> {
    try {
      // Validate password strength
      if (password.length < 8) {
        return { success: false, error: 'Password must be at least 8 characters' };
      }

      if (this.users.has(phoneNumber)) {
        return { success: false, error: 'Account already exists' };
      }

      // Hash password with BCrypt (12 rounds)
      const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

      this.users.set(phoneNumber, {
        phoneNumber,
        passwordHash
      });

      this.saveUsers();

      // Auto-login after account creation
      this.currentUser = phoneNumber;
      this.store.set('currentUser', phoneNumber);

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
      const user = this.users.get(phoneNumber);

      if (!user) {
        return { success: false, error: 'Account not found' };
      }

      // Verify password using BCrypt
      const isValid = await bcrypt.compare(password, user.passwordHash);

      if (!isValid) {
        return { success: false, error: 'Invalid password' };
      }

      this.currentUser = phoneNumber;
      this.store.set('currentUser', phoneNumber);

      return { success: true };
    } catch (error) {
      console.error('[AUTH] Login failed:', error);
      return { success: false, error: (error as Error).message };
    }
  }

  async logout(): Promise<void> {
    this.currentUser = null;
    this.store.delete('currentUser');
  }

  isAuthenticated(): boolean {
    return this.currentUser !== null;
  }

  getCurrentUser(): { phoneNumber: string } | null {
    if (!this.currentUser) {
      return null;
    }

    return { phoneNumber: this.currentUser };
  }
}

export const authService = new AuthService();
