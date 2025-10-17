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
  getSettings: () => Promise<any>;
  updateSettings: (settings: any) => Promise<void>;
  onStatusChanged: (callback: (status: any) => void) => void;
  onStatsUpdate: (callback: (stats: any) => void) => void;
  onConfigDeleted: (callback: () => void) => void;
  onShowImportDialog: (callback: () => void) => void;
  // Auth API
  sendOTP: (phoneNumber: string) => Promise<{ success: boolean; error?: string }>;
  verifyOTP: (phoneNumber: string, code: string) => Promise<{ success: boolean; error?: string }>;
  createAccount: (phoneNumber: string, password: string) => Promise<{ success: boolean; error?: string }>;
  login: (phoneNumber: string, password: string) => Promise<{ success: boolean; error?: string }>;
  logout: () => Promise<void>;
  isAuthenticated: () => Promise<boolean>;
  getCurrentUser: () => Promise<{ phoneNumber: string } | null>;
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
let currentPhoneNumber: string = '';
let threeScene: ThreeScene | null = null;
let isLoadingSettings: boolean = false;

// UI States
const phoneEntryState = document.getElementById('phone-entry-state')!;
const otpVerificationState = document.getElementById('otp-verification-state')!;
const passwordCreationState = document.getElementById('password-creation-state')!;
const loginState = document.getElementById('login-state')!;
const noConfigState = document.getElementById('no-config-state')!;
const vpnState = document.getElementById('vpn-state')!;
const connectingState = document.getElementById('connecting-state')!;
const errorState = document.getElementById('error-state')!;

// Phone Entry Elements
const phoneInput = document.getElementById('phone-input') as HTMLInputElement;
const phoneSubmitBtn = document.getElementById('phone-submit-btn') as HTMLButtonElement;
const loginLink = document.getElementById('login-link')!;

// OTP Elements
const phoneDisplay = document.getElementById('phone-display')!;
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
const loginPhoneInput = document.getElementById('login-phone-input') as HTMLInputElement;
const loginPasswordInput = document.getElementById('login-password-input') as HTMLInputElement;
const loginSubmitBtn = document.getElementById('login-submit-btn') as HTMLButtonElement;
const loginError = document.getElementById('login-error')!;
const signupLink = document.getElementById('signup-link')!;

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
const killSwitchCheck = document.getElementById('kill-switch-check') as HTMLInputElement;

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
  phoneEntryState.style.display = 'none';
  otpVerificationState.style.display = 'none';
  passwordCreationState.style.display = 'none';
  loginState.style.display = 'none';
  noConfigState.style.display = 'none';
  vpnState.style.display = 'none';
  connectingState.style.display = 'none';
  errorState.style.display = 'none';
}

function showState(state: HTMLElement) {
  console.log('[UI] showState called for:', state.id);
  hideAllStates();
  console.log('[UI] All states hidden, now showing:', state.id);
  state.style.display = 'block';
  state.style.opacity = '1';
  state.style.visibility = 'visible';
  console.log('[UI] State display set to block, opacity: 1, visibility: visible');

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
      console.log('[UI] GSAP animation applied');
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

function formatPhoneNumber(phone: string): string {
  // Simple formatting for display
  const cleaned = phone.replace(/\D/g, '');
  if (cleaned.length === 11 && cleaned.startsWith('1')) {
    return `+1 (${cleaned.slice(1, 4)}) ${cleaned.slice(4, 7)}-${cleaned.slice(7)}`;
  }
  return phone;
}

// ===== Onboarding Flow =====

// Step 1: Phone Number Entry
async function handlePhoneSubmit() {
  console.log('[Phone] Submit button clicked');
  const phone = phoneInput.value.trim();
  console.log('[Phone] Phone number entered:', phone);

  if (!phone) {
    console.log('[Phone] No phone number provided');
    alert('Please enter your phone number');
    return;
  }

  console.log('[Phone] Disabling button and sending OTP...');
  phoneSubmitBtn.disabled = true;
  phoneSubmitBtn.textContent = 'Sending...';

  try {
    console.log('[Phone] Calling window.vpn.sendOTP...');
    const result = await window.vpn.sendOTP(phone);
    console.log('[Phone] sendOTP result:', result);

    if (result.success) {
      console.log('[Phone] OTP sent successfully! Showing verification screen...');
      currentPhoneNumber = phone;
      phoneDisplay.textContent = formatPhoneNumber(phone);
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
      console.error('[Phone] sendOTP failed:', result.error);
      alert(result.error || 'Failed to send OTP. Please try again.');
    }
  } catch (error) {
    alert('Error sending OTP: ' + (error as Error).message);
  } finally {
    phoneSubmitBtn.disabled = false;
    phoneSubmitBtn.textContent = 'Continue';
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
    otpError.style.display = 'block';
    gsap.from(otpError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    return;
  }

  otpError.style.display = 'none';
  otpVerifyBtn.disabled = true;
  otpVerifyBtn.textContent = 'Verifying...';

  try {
    const result = await window.vpn.verifyOTP(currentPhoneNumber, code);

    if (result.success) {
      showState(passwordCreationState);

      // Animate password inputs
      gsap.from('.form-group', {
        opacity: 0,
        y: 20,
        duration: 0.5,
        stagger: 0.2,
        ease: 'power2.out'
      });
    } else {
      otpError.textContent = result.error || 'Invalid code. Please try again.';
      otpError.style.display = 'block';
      gsap.from(otpError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });

      // Clear inputs
      otpDigits.forEach(d => d.value = '');
      otpDigits[0].focus();
    }
  } catch (error) {
    otpError.textContent = 'Error verifying code. Please try again.';
    otpError.style.display = 'block';
  } finally {
    otpVerifyBtn.disabled = false;
    otpVerifyBtn.textContent = 'Verify Code';
  }
}

async function handleResendOTP() {
  resendOtpLink.textContent = 'Sending...';

  try {
    const result = await window.vpn.sendOTP(currentPhoneNumber);

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

  if (password.length < 8) {
    passwordError.textContent = 'Password must be at least 8 characters';
    passwordError.style.display = 'block';
    gsap.from(passwordError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    return;
  }

  passwordError.style.display = 'none';
  passwordSubmitBtn.disabled = true;
  passwordSubmitBtn.textContent = 'Creating...';

  try {
    console.log('[Password] Creating account for:', currentPhoneNumber);
    const result = await window.vpn.createAccount(currentPhoneNumber, password);
    console.log('[Password] createAccount result:', result);

    if (result.success) {
      console.log('[Password] Account created successfully! Transitioning to main app...');
      // Account created! Show success animation then go to main app
      gsap.to(passwordCreationState, {
        scale: 0.95,
        opacity: 0,
        duration: 0.4,
        onComplete: () => {
          console.log('[Password] Animation complete, calling checkAuthAndShowUI()');
          checkAuthAndShowUI();
        }
      });
    } else {
      console.error('[Password] Failed to create account:', result.error);
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
  const phone = loginPhoneInput.value.trim();
  const password = loginPasswordInput.value;

  if (!phone || !password) {
    loginError.textContent = 'Please fill in all fields';
    loginError.style.display = 'block';
    gsap.from(loginError, { x: -10, duration: 0.1, repeat: 5, yoyo: true });
    return;
  }

  loginError.style.display = 'none';
  loginSubmitBtn.disabled = true;
  loginSubmitBtn.textContent = 'Signing In...';

  try {
    const result = await window.vpn.login(phone, password);

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
      loginError.textContent = result.error || 'Invalid credentials';
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

async function handleLogout() {
  const confirmed = confirm('Are you sure you want to logout?');
  if (confirmed) {
    try {
      await window.vpn.logout();
      currentConfig = null;
      currentStatus = null;
      currentStats = null;
      showState(phoneEntryState);
    } catch (error) {
      alert('Error logging out');
    }
  }
}

// ===== VPN Functions =====
async function updateUI() {
  console.log('[UI] updateUI called, currentConfig:', currentConfig);

  if (!currentConfig) {
    console.log('[UI] No config, showing noConfigState (import screen)');
    showState(noConfigState);
    return;
  }

  if (currentStatus?.error && !currentStatus.connected && !currentStatus.connecting) {
    console.log('[UI] Error state, showing error screen');
    errorMessageText.textContent = currentStatus.error;
    showState(errorState);
    return;
  }

  if (currentStatus?.connecting) {
    console.log('[UI] Connecting state, showing connecting screen');
    showState(connectingState);
    return;
  }

  console.log('[UI] Showing VPN state screen');
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
    console.log('[Import] Opening file dialog...');
    const result = await window.vpn.importConfig();
    console.log('[Import] Result:', result);

    if (result.success) {
      console.log('[Import] Success! Loading config...');
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
      console.error('[Import] Failed:', result.error);
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
      killSwitch: killSwitchCheck.checked || false,
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
    killSwitchCheck.checked = settings.killSwitch || false;
  } finally {
    isLoadingSettings = false;
  }
}

async function checkAuthAndShowUI() {
  try {
    console.log('[Auth] Checking authentication status...');
    const isAuth = await window.vpn.isAuthenticated();
    console.log('[Auth] Is authenticated:', isAuth);

    if (isAuth) {
      console.log('[Auth] User is authenticated, loading VPN UI...');
      console.log('[Auth] Loading config...');
      await loadConfig();
      console.log('[Auth] Config loaded:', currentConfig);
      console.log('[Auth] Loading status...');
      await loadStatus();
      console.log('[Auth] Status loaded:', currentStatus);
      console.log('[Auth] Loading stats...');
      await loadStats();
      console.log('[Auth] Stats loaded:', currentStats);
      console.log('[Auth] Loading settings...');
      await loadSettings();
      console.log('[Auth] Settings loaded');
      console.log('[Auth] Calling updateUI()...');
      updateUI();
    } else {
      console.log('[Auth] User not authenticated, showing phone entry screen...');
      showState(phoneEntryState);
    }
  } catch (error) {
    console.error('[Auth] Error in checkAuthAndShowUI:', error);
    // Show phone entry as fallback
    showState(phoneEntryState);
  }
}

// ===== Initialization =====
async function initialize() {
  console.log('[App] Initializing WorkVPN Desktop...');

  try {
    // Initialize Three.js scene
    console.log('[App] Initializing Three.js scene...');
    initThreeScene();

    // Setup OTP inputs
    console.log('[App] Setting up OTP inputs...');
    setupOTPInputs();

    // Event listeners for onboarding
    phoneSubmitBtn.addEventListener('click', handlePhoneSubmit);
    phoneInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') handlePhoneSubmit();
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
      showState(phoneEntryState);
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
    killSwitchCheck.addEventListener('change', handleSettingsChange);

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
    console.log('[App] Checking authentication and showing UI...');
    await checkAuthAndShowUI();
    console.log('[App] UI displayed');

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

    console.log('[App] Initialization complete!');
  } catch (error) {
    console.error('[App] Fatal error during initialization:', error);
    // Fallback: show phone entry screen
    showState(phoneEntryState);
  }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initialize);
} else {
  initialize();
}
