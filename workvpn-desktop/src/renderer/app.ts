// @ts-nocheck
// GSAP and THREE.js are loaded from CDN in index.html

// TypeScript declarations for window.vpn
interface VPNApi {
  importConfig: () => Promise<{ success: boolean; error?: string }>;
  hasConfig: () => Promise<boolean>;
  getConfigInfo: () => Promise<any>;
  deleteConfig: () => Promise<void>;
  connect: () => Promise<{ success: boolean; error?: string }>;
  disconnect: () => Promise<void>;
  getStatus: () => Promise<any>;
  getStats: () => Promise<any>;
  setCredentials: (username: string, password: string) => Promise<{ success: boolean; error?: string }>;
  getSettings: () => Promise<any>;
  updateSettings: (settings: any) => Promise<void>;
  onStatusChanged: (callback: (status: any) => void) => void;
  onStatsUpdate: (callback: (stats: any) => void) => void;
  onConfigDeleted: (callback: () => void) => void;
  onShowImportDialog: (callback: () => void) => void;
  // Auth API
  sendOTP: (email: string) => Promise<{ success: boolean; error?: string }>;
  verifyOTP: (email: string, code: string) => Promise<{ success: boolean; error?: string }>;
  createAccount: (email: string, password: string, otpCode: string) => Promise<{ success: boolean; error?: string }>;
  login: (email: string, password: string) => Promise<{ success: boolean; error?: string }>;
  logout: () => Promise<void>;
  isAuthenticated: () => Promise<boolean>;
  getCurrentUser: () => Promise<{ email: string } | null>;
}

declare global {
  interface Window {
    vpn: VPNApi;
  }
}

// State management
let currentStatus: any = null;
let currentStats: any = null;
let currentConfig: any = null;
let currentEmail: string = '';
let currentOTPCode: string = ''; // Store verified OTP code for account creation
let threeScene: ThreeScene | null = null;
let isLoadingSettings: boolean = false;

// UI States
const emailEntryState = document.getElementById('email-entry-state')!;
const otpVerificationState = document.getElementById('otp-verification-state')!;
const passwordCreationState = document.getElementById('password-creation-state')!;
const loginState = document.getElementById('login-state')!;
const noConfigState = document.getElementById('no-config-state')!;
const vpnCredentialsState = document.getElementById('vpn-credentials-state')!;
const vpnState = document.getElementById('vpn-state')!;
const connectingState = document.getElementById('connecting-state')!;
const errorState = document.getElementById('error-state')!;

// Email Entry Elements
const emailInput = document.getElementById('email-input') as HTMLInputElement;
const emailSubmitBtn = document.getElementById('email-submit-btn') as HTMLButtonElement;
const loginLink = document.getElementById('login-link')!;

// OTP Elements
const emailDisplay = document.getElementById('email-display')!;
const otpDigits: HTMLInputElement[] = [
  document.getElementById('otp-1') as HTMLInputElement,
  document.getElementById('otp-2') as HTMLInputElement,
  document.getElementById('otp-3') as HTMLInputElement,
  document.getElementById('otp-4') as HTMLInputElement,
  document.getElementById('otp-5') as HTMLInputElement,
  document.getElementById('otp-6') as HTMLInputElement,
];
const otpVerifyBtn = document.getElementById('otp-verify-btn') as HTMLButtonElement;
const otpError = document.getElementById('otp-error')!;
const resendOtpLink = document.getElementById('resend-otp-link')!;

// Password Creation Elements
const passwordInput = document.getElementById('password-input') as HTMLInputElement;
const passwordConfirmInput = document.getElementById('password-confirm-input') as HTMLInputElement;
const passwordSubmitBtn = document.getElementById('password-submit-btn') as HTMLButtonElement;
const passwordError = document.getElementById('password-error')!;

// Login Elements
const loginEmailInput = document.getElementById('login-email-input') as HTMLInputElement;
const loginPasswordInput = document.getElementById('login-password-input') as HTMLInputElement;
const loginSubmitBtn = document.getElementById('login-submit-btn') as HTMLButtonElement;
const loginError = document.getElementById('login-error')!;
const signupLink = document.getElementById('signup-link')!;

// VPN Credentials Elements
const vpnUsernameInput = document.getElementById('vpn-username-input') as HTMLInputElement;
const vpnPasswordInput = document.getElementById('vpn-password-input') as HTMLInputElement;
const vpnCredentialsSubmitBtn = document.getElementById('vpn-credentials-submit-btn') as HTMLButtonElement;
const vpnCredentialsBackBtn = document.getElementById('vpn-credentials-back-btn') as HTMLButtonElement;
const vpnCredentialsError = document.getElementById('vpn-credentials-error')!;

// VPN Elements
const statusIcon = document.getElementById('status-icon')!;
const statusText = document.getElementById('status-text')!;
const serverAddress = document.getElementById('server-address')!;
const protocol = document.getElementById('protocol')!;
const localIp = document.getElementById('local-ip')!;
const duration = document.getElementById('duration')!;
const bytesIn = document.getElementById('bytes-in')!;
const bytesOut = document.getElementById('bytes-out')!;
const errorMessageText = document.getElementById('error-message-text')!;

const importBtn = document.getElementById('import-btn') as HTMLButtonElement;
const connectBtn = document.getElementById('connect-btn') as HTMLButtonElement;
const disconnectBtn = document.getElementById('disconnect-btn') as HTMLButtonElement;
const deleteConfigBtn = document.getElementById('delete-config-btn') as HTMLButtonElement;
const retryBtn = document.getElementById('retry-btn') as HTMLButtonElement;
const logoutBtn = document.getElementById('logout-btn') as HTMLButtonElement;
const vpnLogoutBtn = document.getElementById('vpn-logout-btn') as HTMLButtonElement;

const autoConnectCheck = document.getElementById('auto-connect-check') as HTMLInputElement;
const autoStartCheck = document.getElementById('auto-start-check') as HTMLInputElement;
// Kill switch removed - will be implemented in future version with proper platform-specific firewall rules
// const killSwitchCheck = document.getElementById('kill-switch-check') as HTMLInputElement;

// ===== Three.js Scene Setup =====
function initThreeScene() {
  try {
    const container = document.getElementById('three-canvas');
    if (!container) {
      console.error('[ThreeScene] Container #three-canvas not found');
      return;
    }
    if (typeof THREE === 'undefined') {
      console.error('[ThreeScene] THREE.js not loaded');
      return;
    }
    if (typeof ThreeScene === 'undefined') {
      console.error('[ThreeScene] ThreeScene class not defined');
      return;
    }
    console.log('[ThreeScene] Initializing scene...');
    threeScene = new ThreeScene(container);
    console.log('[ThreeScene] Scene initialized successfully');
  } catch (error) {
    console.error('[ThreeScene] Error initializing:', error);
  }
}

// ===== Utility Functions =====
function hideAllStates() {
  emailEntryState.style.display = 'none';
  otpVerificationState.style.display = 'none';
  passwordCreationState.style.display = 'none';
  loginState.style.display = 'none';
  noConfigState.style.display = 'none';
  vpnCredentialsState.style.display = 'none';
  vpnState.style.display = 'none';
  connectingState.style.display = 'none';
  errorState.style.display = 'none';
}

function showState(state: HTMLElement) {
  if (process.env.NODE_ENV !== 'production') {
    console.log('[UI] showState called for:', state.id);
  }
  hideAllStates();
  state.style.display = 'block';
  state.style.opacity = '1';
  state.style.visibility = 'visible';

  // GSAP animation
  try {
    if (typeof gsap !== 'undefined') {
      gsap.fromTo(state,
        {
          opacity: 0,
          y: 30
        },
        {
          opacity: 1,
          y: 0,
          duration: 0.6,
          ease: 'power3.out',
          clearProps: 'all'
        }
      );
    } else {
      console.error('[UI] GSAP is not defined!');
    }
  } catch (error) {
    console.error('[UI] Error applying GSAP animation:', error);
  }
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 MB';
  const mb = bytes / (1024 * 1024);
  return mb.toFixed(2) + ' MB';
}

function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  if (hours > 0) {
    return `${hours}h ${minutes}m ${secs}s`;
  } else if (minutes > 0) {
    return `${minutes}m ${secs}s`;
  } else {
    return `${secs}s`;
  }
}

// ===== Onboarding Flow =====

// Step 1: Email Entry
async function handleEmailSubmit() {
  const email = emailInput.value.trim();

  // Validate email format
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!email) {
    alert('Please enter your email address');
    return;
  }

  if (!emailRegex.test(email)) {
    alert('Invalid email format. Please enter a valid email address');
    return;
  }

  emailSubmitBtn.disabled = true;
  emailSubmitBtn.textContent = 'Sending...';

  try {
    const result = await window.vpn.sendOTP(email);

    if (result.success) {
      currentEmail = email;
      emailDisplay.textContent = email;
      showState(otpVerificationState);

      // Focus first OTP digit
      setTimeout(() => otpDigits[0].focus(), 300);

      // Animate OTP inputs
      gsap.from('.otp-digit', {
        scale: 0,
        opacity: 0,
        duration: 0.4,
        stagger: 0.1,
        ease: 'back.out(1.7)'
      });
    } else {
      alert(result.error || 'Failed to send OTP. Please try again.');
    }
  } catch (error) {
    alert('Error sending OTP: ' + (error as Error).message);
  } finally {
    emailSubmitBtn.disabled = false;
    emailSubmitBtn.textContent = 'Continue';
  }
}

// Step 2: OTP Verification
function setupOTPInputs() {
  otpDigits.forEach((input, index) => {
    input.addEventListener('input', (e) => {
      const value = (e.target as HTMLInputElement).value;

      if (value.length === 1 && index < otpDigits.length - 1) {
        otpDigits[index + 1].focus();
      }

      // Auto-verify when all digits filled
      if (index === otpDigits.length - 1 && value.length === 1) {
        const allFilled = otpDigits.every(d => d.value.length === 1);
        if (allFilled) {
          handleOTPVerify();
        }
      }
    });

    input.addEventListener('keydown', (e) => {
      if (e.key === 'Backspace' && !input.value && index > 0) {
        otpDigits[index - 1].focus();
      }
    });
  });
}

async function handleOTPVerify() {
  const code = otpDigits.map(d => d.value).join('');

  if (code.length !== 6) {
    otpError.textContent = 'Please enter all 6 digits';
    otpError.style.display = 'block';
    if (typeof gsap !== 'undefined') {
      gsap.from(otpError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    }
    return;
  }

  otpError.style.display = 'none';
  otpVerifyBtn.disabled = true;
  otpVerifyBtn.textContent = 'Verifying...';

  try {
    const result = await window.vpn.verifyOTP(currentEmail, code);

    if (result.success) {
      // Store the verified OTP code for account creation
      currentOTPCode = code;

      try {
        // Ensure password creation state exists
        if (!passwordCreationState) {
          throw new Error('Password creation state element not found');
        }

        // Show password creation state
        showState(passwordCreationState);

        // Animate password inputs if GSAP is available
        if (typeof gsap !== 'undefined') {
          try {
            gsap.from('.form-group', {
              opacity: 0,
              y: 20,
              duration: 0.5,
              stagger: 0.2,
              ease: 'power2.out'
            });
          } catch (animError) {
            if (process.env.NODE_ENV !== 'production') {
              console.warn('[OTP] GSAP animation failed, but state transition succeeded:', animError);
            }
          }
        }

        // Focus first password input after animation
        setTimeout(() => {
          passwordInput?.focus();
        }, 600);

      } catch (stateError) {
        console.error('[OTP] Critical error during state transition:', stateError);
        otpError.textContent = 'UI error occurred. Please refresh and try again.';
        otpError.style.display = 'block';

        // Fallback: try showing password state without animation
        try {
          passwordCreationState.style.display = 'block';
          hideAllStates();
          passwordCreationState.style.display = 'block';
        } catch (fallbackError) {
          console.error('[OTP] Fallback also failed:', fallbackError);
        }
      }
    } else {
      otpError.textContent = result.error || 'Invalid code. Please try again.';
      otpError.style.display = 'block';

      if (typeof gsap !== 'undefined') {
        gsap.from(otpError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
      }

      // Clear inputs
      otpDigits.forEach(d => d.value = '');
      otpDigits[0].focus();
    }
  } catch (error) {
    console.error('[OTP] Exception during verification:', error);
    otpError.textContent = 'Network error. Please check connection and try again.';
    otpError.style.display = 'block';
  } finally {
    otpVerifyBtn.disabled = false;
    otpVerifyBtn.textContent = 'Verify Code';
  }
}

async function handleResendOTP() {
  resendOtpLink.textContent = 'Sending...';

  try {
    const result = await window.vpn.sendOTP(currentEmail);

    if (result.success) {
      resendOtpLink.textContent = 'Code sent!';
      setTimeout(() => {
        resendOtpLink.textContent = 'Resend';
      }, 3000);
    } else {
      alert(result.error || 'Failed to resend code');
      resendOtpLink.textContent = 'Resend';
    }
  } catch (error) {
    alert('Error resending code');
    resendOtpLink.textContent = 'Resend';
  }
}

// Step 3: Password Creation
async function handlePasswordSubmit() {
  const password = passwordInput.value;
  const confirmPassword = passwordConfirmInput.value;

  if (!password || !confirmPassword) {
    passwordError.textContent = 'Please fill in all fields';
    passwordError.style.display = 'block';
    gsap.from(passwordError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    return;
  }

  if (password !== confirmPassword) {
    passwordError.textContent = 'Passwords don\'t match';
    passwordError.style.display = 'block';
    gsap.from(passwordError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    return;
  }

  // Strengthened password validation (12 characters minimum with complexity requirements)
  if (password.length < 12) {
    passwordError.textContent = 'Password must be at least 12 characters';
    passwordError.style.display = 'block';
    gsap.from(passwordError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    return;
  }

  // Check for password complexity: uppercase, lowercase, number, and special character
  const hasUppercase = /[A-Z]/.test(password);
  const hasLowercase = /[a-z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  const hasSpecial = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password);

  if (!hasUppercase || !hasLowercase || !hasNumber || !hasSpecial) {
    passwordError.textContent = 'Password must include uppercase, lowercase, number, and special character';
    passwordError.style.display = 'block';
    gsap.from(passwordError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    return;
  }

  passwordError.style.display = 'none';
  passwordSubmitBtn.disabled = true;
  passwordSubmitBtn.textContent = 'Creating...';

  try {
    const result = await window.vpn.createAccount(currentEmail, password, currentOTPCode);

    if (result.success) {
      // Clear sensitive data
      currentOTPCode = '';
      passwordInput.value = '';
      passwordConfirmInput.value = '';

      // Account created! Show success animation then go to main app
      gsap.to(passwordCreationState, {
        scale: 0.95,
        opacity: 0,
        duration: 0.4,
        onComplete: () => {
          checkAuthAndShowUI();
        }
      });
    } else {
      passwordError.textContent = result.error || 'Failed to create account';
      passwordError.style.display = 'block';
      gsap.from(passwordError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    }
  } catch (error) {
    console.error('[Password] Exception during account creation:', error);
    passwordError.textContent = 'Error creating account';
    passwordError.style.display = 'block';
  } finally {
    passwordSubmitBtn.disabled = false;
    passwordSubmitBtn.textContent = 'Create Account';
  }
}

// Step 4: Login
async function handleLogin() {
  const email = loginEmailInput.value.trim();
  const password = loginPasswordInput.value;

  if (!email || !password) {
    loginError.textContent = 'Please fill in all fields';
    loginError.style.display = 'block';
    gsap.from(loginError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    return;
  }

  loginError.style.display = 'none';
  loginSubmitBtn.disabled = true;
  loginSubmitBtn.textContent = 'Signing In...';

  try {
    const result = await window.vpn.login(email, password);

    if (result.success) {
      gsap.to(loginState, {
        scale: 0.95,
        opacity: 0,
        duration: 0.4,
        onComplete: () => {
          checkAuthAndShowUI();
        }
      });
    } else {
      loginError.textContent = result.error || 'Invalid email or password';
      loginError.style.display = 'block';
      gsap.from(loginError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    }
  } catch (error) {
    loginError.textContent = 'Error signing in';
    loginError.style.display = 'block';
  } finally {
    loginSubmitBtn.disabled = false;
    loginSubmitBtn.textContent = 'Sign In';
  }
}

// VPN Credentials Handler
async function handleVPNCredentialsSubmit() {
  const username = vpnUsernameInput.value.trim();
  const password = vpnPasswordInput.value;

  if (!username || !password) {
    vpnCredentialsError.textContent = 'Please enter both username and password';
    vpnCredentialsError.style.display = 'block';
    gsap.from(vpnCredentialsError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    return;
  }

  vpnCredentialsError.style.display = 'none';
  vpnCredentialsSubmitBtn.disabled = true;
  vpnCredentialsSubmitBtn.textContent = 'Connecting...';

  try {
    // Store credentials for VPN connection
    const credentialsResult = await window.vpn.setCredentials(username, password);
    if (!credentialsResult.success) {
      vpnCredentialsError.textContent = credentialsResult.error || 'Failed to save credentials';
      vpnCredentialsError.style.display = 'block';
      gsap.from(vpnCredentialsError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
      return;
    }

    // Attempt VPN connection with credentials
    const result = await window.vpn.connect();

    if (result.success) {
      // Connection successful - show VPN interface
      gsap.to(vpnCredentialsState, {
        scale: 0.95,
        opacity: 0,
        duration: 0.4,
        onComplete: () => {
          updateUI();
        }
      });
    } else {
      vpnCredentialsError.textContent = result.error || 'Failed to connect with provided credentials';
      vpnCredentialsError.style.display = 'block';
      gsap.from(vpnCredentialsError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    }
  } catch (error) {
    vpnCredentialsError.textContent = 'Connection error. Please check your credentials and try again.';
    vpnCredentialsError.style.display = 'block';
  } finally {
    vpnCredentialsSubmitBtn.disabled = false;
    vpnCredentialsSubmitBtn.textContent = 'Connect to VPN';
  }
}

async function handleLogout() {
  const confirmed = confirm('Are you sure you want to logout?');
  if (confirmed) {
    try {
      await window.vpn.logout();
      currentConfig = null;
      currentStatus = null;
      currentStats = null;
      showState(emailEntryState);
    } catch (error) {
      alert('Error logging out');
    }
  }
}

// ===== VPN Functions =====
async function updateUI() {
  if (!currentConfig) {
    showState(noConfigState);
    return;
  }

  // Check if VPN requires authentication and we don't have credentials yet
  if (currentConfig.parsed?.requiresAuth &&
      (!currentConfig.parsed.username || !currentConfig.parsed.password)) {
    showState(vpnCredentialsState);
    return;
  }

  if (currentStatus?.error && !currentStatus.connected && !currentStatus.connecting) {
    errorMessageText.textContent = currentStatus.error;
    showState(errorState);
    return;
  }

  if (currentStatus?.connecting) {
    showState(connectingState);
    return;
  }

  showState(vpnState);

  // Update status with GSAP animation
  if (currentStatus?.connected) {
    statusIcon.className = 'status-icon connected';
    statusText.textContent = 'Connected';
    connectBtn.style.display = 'none';
    disconnectBtn.style.display = 'block';

    gsap.to(statusIcon, {
      rotation: 360,
      duration: 1,
      ease: 'elastic.out(1, 0.3)'
    });
  } else {
    statusIcon.className = 'status-icon disconnected';
    statusText.textContent = 'Disconnected';
    connectBtn.style.display = 'block';
    disconnectBtn.style.display = 'none';
  }

  // Update server info
  if (currentConfig) {
    serverAddress.textContent = currentConfig.server || '-';
    protocol.textContent = `${currentConfig.protocol?.toUpperCase() || 'UDP'}:${currentConfig.port || 1194}`;
  }

  if (currentStatus?.localIp) {
    localIp.textContent = currentStatus.localIp;
  } else {
    localIp.textContent = '-';
  }

  // Update stats with animated numbers
  if (currentStats) {
    animateValue(bytesIn, formatBytes(currentStats.bytesIn));
    animateValue(bytesOut, formatBytes(currentStats.bytesOut));
    duration.textContent = formatDuration(currentStats.duration);
  } else {
    bytesIn.textContent = '0 MB';
    bytesOut.textContent = '0 MB';
    duration.textContent = '-';
  }
}

function animateValue(element: HTMLElement, newValue: string) {
  gsap.to(element, {
    opacity: 0.5,
    duration: 0.2,
    onComplete: () => {
      element.textContent = newValue;
      gsap.to(element, { opacity: 1, duration: 0.2 });
    }
  });
}

async function handleImport() {
  importBtn.disabled = true;
  importBtn.textContent = 'Importing...';

  try {
    const result = await window.vpn.importConfig();

    if (result.success) {
      await loadConfig();
      updateUI();

      // Show success animation
      gsap.from('.status-section', {
        scale: 0.95,
        opacity: 0,
        duration: 0.5,
        ease: 'back.out(1.7)'
      });
    } else {
      alert(`Failed to import config: ${result.error || 'No file selected or invalid configuration'}`);
    }
  } catch (error) {
    console.error('[Import] Exception:', error);
    alert(`Import error: ${(error as Error).message}`);
  } finally {
    importBtn.disabled = false;
    importBtn.textContent = 'Import .ovpn File';
  }
}

async function handleConnect() {
  try {
    connectBtn.disabled = true;

    // Button animation
    gsap.to(connectBtn, { scale: 0.95, duration: 0.1, yoyo: true, repeat: 1 });

    const result = await window.vpn.connect();
    if (!result.success) {
      alert(`Connection failed: ${result.error || 'Unknown error'}`);
    }
  } catch (error) {
    alert(`Connect error: ${(error as Error).message}`);
  } finally {
    connectBtn.disabled = false;
  }
}

async function handleDisconnect() {
  try {
    disconnectBtn.disabled = true;

    gsap.to(disconnectBtn, { scale: 0.95, duration: 0.1, yoyo: true, repeat: 1 });

    await window.vpn.disconnect();
  } catch (error) {
    alert(`Disconnect error: ${(error as Error).message}`);
  } finally {
    disconnectBtn.disabled = false;
  }
}

async function handleDeleteConfig() {
  const confirmed = confirm('Are you sure you want to delete this VPN configuration?');
  if (confirmed) {
    try {
      await window.vpn.deleteConfig();
      currentConfig = null;
      currentStatus = null;
      currentStats = null;
      updateUI();
    } catch (error) {
      alert(`Delete error: ${(error as Error).message}`);
    }
  }
}

async function handleRetry() {
  await loadStatus();
  updateUI();
}

async function handleSettingsChange() {
  // Prevent triggering during initial load
  if (isLoadingSettings) {
    return;
  }

  try {
    await window.vpn.updateSettings({
      autoConnect: autoConnectCheck.checked || false,
      autoStart: autoStartCheck.checked || false,
      killSwitch: false, // Kill switch removed - will be implemented in future version
    });
  } catch (error) {
    console.error('Settings update error:', error);
  }
}

// Load data functions
async function loadConfig() {
  const hasConfig = await window.vpn.hasConfig();
  if (hasConfig) {
    currentConfig = await window.vpn.getConfigInfo();
  } else {
    currentConfig = null;
  }
}

async function loadStatus() {
  currentStatus = await window.vpn.getStatus();
}

async function loadStats() {
  currentStats = await window.vpn.getStats();
}

async function loadSettings() {
  isLoadingSettings = true;
  try {
    const settings = await window.vpn.getSettings();
    autoConnectCheck.checked = settings.autoConnect || false;
    autoStartCheck.checked = settings.autoStart || false;
    // Kill switch removed - will be implemented in future version
  } finally {
    isLoadingSettings = false;
  }
}

async function checkAuthAndShowUI() {
  try {
    const isAuth = await window.vpn.isAuthenticated();

    if (isAuth) {
      await loadConfig();
      await loadStatus();
      await loadStats();
      await loadSettings();
      updateUI();
    } else {
      showState(emailEntryState);
    }
  } catch (error) {
    console.error('[Auth] Error in checkAuthAndShowUI:', error);
    // Show email entry as fallback
    showState(emailEntryState);
  }
}

// ===== Initialization =====
async function initialize() {
  if (process.env.NODE_ENV !== 'production') {
    console.log('[App] Initializing WorkVPN Desktop...');
  }

  try {
    // Initialize Three.js scene
    initThreeScene();

    // Setup OTP inputs
    setupOTPInputs();

    // Event listeners for onboarding
    emailSubmitBtn.addEventListener('click', handleEmailSubmit);
    emailInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') handleEmailSubmit();
    });
    loginLink.addEventListener('click', (e) => {
      e.preventDefault();
      showState(loginState);
    });

    otpVerifyBtn.addEventListener('click', handleOTPVerify);
    resendOtpLink.addEventListener('click', (e) => {
      e.preventDefault();
      handleResendOTP();
    });

    passwordSubmitBtn.addEventListener('click', handlePasswordSubmit);
    passwordConfirmInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') handlePasswordSubmit();
    });

    loginSubmitBtn.addEventListener('click', handleLogin);
    loginPasswordInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') handleLogin();
    });
    signupLink.addEventListener('click', (e) => {
      e.preventDefault();
      showState(emailEntryState);
    });

    // VPN Credentials event listeners
    vpnCredentialsSubmitBtn.addEventListener('click', handleVPNCredentialsSubmit);
    vpnCredentialsBackBtn.addEventListener('click', (e) => {
      e.preventDefault();  
      showState(noConfigState);
    });
    vpnPasswordInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') handleVPNCredentialsSubmit();
    });

    logoutBtn.addEventListener('click', handleLogout);
    vpnLogoutBtn.addEventListener('click', handleLogout);

    // Event listeners for VPN
    importBtn.addEventListener('click', handleImport);
    connectBtn.addEventListener('click', handleConnect);
    disconnectBtn.addEventListener('click', handleDisconnect);
    deleteConfigBtn.addEventListener('click', handleDeleteConfig);
    retryBtn.addEventListener('click', handleRetry);

    autoConnectCheck.addEventListener('change', handleSettingsChange);
    autoStartCheck.addEventListener('change', handleSettingsChange);
    // Kill switch removed - will be implemented in future version
    // killSwitchCheck.addEventListener('change', handleSettingsChange);

    // Listen for status changes
    window.vpn.onStatusChanged((status) => {
      currentStatus = status;
      updateUI();
    });

    // Listen for stats updates
    window.vpn.onStatsUpdate((stats) => {
      currentStats = stats;
      updateUI();
    });

    // Listen for config deletion
    window.vpn.onConfigDeleted(() => {
      currentConfig = null;
      currentStatus = null;
      currentStats = null;
      updateUI();
    });

    // Listen for import dialog trigger from tray
    window.vpn.onShowImportDialog(() => {
      handleImport();
    });

    // Check auth status and show appropriate UI
    await checkAuthAndShowUI();

    // Animate title bar
    gsap.from('.title-bar', {
      y: -40,
      opacity: 0,
      duration: 0.8,
      ease: 'power3.out'
    });

    // Animate settings
    gsap.from('.settings-section', {
      y: 40,
      opacity: 0,
      duration: 0.8,
      delay: 0.2,
      ease: 'power3.out'
    });

    if (process.env.NODE_ENV !== 'production') {
      console.log('[App] Initialization complete!');
    }
  } catch (error) {
    console.error('[App] Fatal error during initialization:', error);
    // Fallback: show email entry screen
    showState(emailEntryState);
  }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initialize);
} else {
  initialize();
}
