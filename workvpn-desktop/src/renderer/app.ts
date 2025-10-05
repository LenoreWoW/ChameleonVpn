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
}

declare global {
  interface Window {
    vpn: VPNApi;
  }
}

// Export to make this a module
export {};

// State management
let currentStatus: any = null;
let currentStats: any = null;
let currentConfig: any = null;

// UI Elements
const noConfigState = document.getElementById('no-config-state')!;
const vpnState = document.getElementById('vpn-state')!;
const connectingState = document.getElementById('connecting-state')!;
const errorState = document.getElementById('error-state')!;

const statusIcon = document.getElementById('status-icon')!;
const statusText = document.getElementById('status-text')!;
const serverAddress = document.getElementById('server-address')!;
const protocol = document.getElementById('protocol')!;
const localIp = document.getElementById('local-ip')!;
const duration = document.getElementById('duration')!;
const bytesIn = document.getElementById('bytes-in')!;
const bytesOut = document.getElementById('bytes-out')!;
const errorMessage = document.getElementById('error-message')!;

const importBtn = document.getElementById('import-btn') as HTMLButtonElement;
const connectBtn = document.getElementById('connect-btn') as HTMLButtonElement;
const disconnectBtn = document.getElementById('disconnect-btn') as HTMLButtonElement;
const deleteConfigBtn = document.getElementById('delete-config-btn') as HTMLButtonElement;
const retryBtn = document.getElementById('retry-btn') as HTMLButtonElement;

const autoConnectCheck = document.getElementById('auto-connect-check') as HTMLInputElement;
const autoStartCheck = document.getElementById('auto-start-check') as HTMLInputElement;
const killSwitchCheck = document.getElementById('kill-switch-check') as HTMLInputElement;

// Utility Functions
function hideAllStates() {
  noConfigState.style.display = 'none';
  vpnState.style.display = 'none';
  connectingState.style.display = 'none';
  errorState.style.display = 'none';
}

function showState(state: HTMLElement) {
  hideAllStates();
  state.style.display = 'block';
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

// Update UI based on status
function updateUI() {
  if (!currentConfig) {
    // No config imported
    showState(noConfigState);
    return;
  }

  if (currentStatus?.error && !currentStatus.connected && !currentStatus.connecting) {
    // Show error state
    errorMessage.textContent = currentStatus.error;
    showState(errorState);
    return;
  }

  if (currentStatus?.connecting) {
    // Show connecting state
    showState(connectingState);
    return;
  }

  // Show VPN state (connected or disconnected)
  showState(vpnState);

  // Update status icon and text
  if (currentStatus?.connected) {
    statusIcon.className = 'status-icon connected';
    statusText.textContent = 'Connected';
    connectBtn.style.display = 'none';
    disconnectBtn.style.display = 'block';
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

  // Update stats
  if (currentStats) {
    bytesIn.textContent = formatBytes(currentStats.bytesIn);
    bytesOut.textContent = formatBytes(currentStats.bytesOut);
    duration.textContent = formatDuration(currentStats.duration);
  } else {
    bytesIn.textContent = '0 MB';
    bytesOut.textContent = '0 MB';
    duration.textContent = '-';
  }
}

// Event Handlers
async function handleImport() {
  try {
    const result = await window.vpn.importConfig();
    if (result.success) {
      await loadConfig();
      updateUI();
    } else {
      alert(`Failed to import config: ${result.error || 'Unknown error'}`);
    }
  } catch (error) {
    alert(`Import error: ${(error as Error).message}`);
  }
}

async function handleConnect() {
  try {
    connectBtn.disabled = true;
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
  try {
    await window.vpn.updateSettings({
      autoConnect: autoConnectCheck.checked,
      autoStart: autoStartCheck.checked,
      killSwitch: killSwitchCheck.checked,
    });
  } catch (error) {
    console.error('Settings update error:', error);
  }
}

// Load initial data
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
  const settings = await window.vpn.getSettings();
  autoConnectCheck.checked = settings.autoConnect || false;
  autoStartCheck.checked = settings.autoStart || false;
  killSwitchCheck.checked = settings.killSwitch || false;
}

async function initialize() {
  // Load initial data
  await loadConfig();
  await loadStatus();
  await loadStats();
  await loadSettings();

  // Update UI
  updateUI();

  // Set up event listeners
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
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initialize);
} else {
  initialize();
}
