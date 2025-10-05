import Store from 'electron-store';

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

    // Load current session
    this.currentUser = this.store.get('currentUser', null) as string | null;
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

      // In production, send SMS via Twilio/similar
      console.log(`[AUTH] OTP for ${phoneNumber}: ${otpCode}`);

      // For demo, show OTP in console
      return { success: true };
    } catch (error) {
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
      if (this.users.has(phoneNumber)) {
        return { success: false, error: 'Account already exists' };
      }

      // In production, hash password with bcrypt
      const passwordHash = Buffer.from(password).toString('base64');

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
      return { success: false, error: (error as Error).message };
    }
  }

  async login(phoneNumber: string, password: string): Promise<{ success: boolean; error?: string }> {
    const user = this.users.get(phoneNumber);

    if (!user) {
      return { success: false, error: 'Account not found' };
    }

    // In production, compare hashed passwords
    const passwordHash = Buffer.from(password).toString('base64');

    if (user.passwordHash !== passwordHash) {
      return { success: false, error: 'Invalid password' };
    }

    this.currentUser = phoneNumber;
    this.store.set('currentUser', phoneNumber);

    return { success: true };
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
