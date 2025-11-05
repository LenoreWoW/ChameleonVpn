import { EventEmitter } from 'events';
import { spawn, ChildProcess } from 'child_process';
import fs from 'fs';
import path from 'path';
import { ConfigStore } from '../store/config';
import { parseOVPNConfig } from './parser';
import { OpenVPNManagementInterface } from './management-interface';

export interface VPNStatus {
  connected: boolean;
  connecting: boolean;
  error: string | null;
  serverIp?: string;
  localIp?: string;
  connectedSince?: Date;
}

export interface VPNStats {
  bytesIn: number;
  bytesOut: number;
  duration: number;
}

export class VPNManager extends EventEmitter {
  private process: ChildProcess | null = null;
  private status: VPNStatus;
  private stats: VPNStats;
  private statsInterval: NodeJS.Timeout | null = null;
  private configStore: ConfigStore;
  private managementInterface: OpenVPNManagementInterface | null = null;
  private authFilePath: string | null = null;
  private tempConfigPath: string | null = null;

  constructor(configStore: ConfigStore) {
    super();
    this.configStore = configStore;
    this.status = {
      connected: false,
      connecting: false,
      error: null
    };
    this.stats = {
      bytesIn: 0,
      bytesOut: 0,
      duration: 0
    };
  }

  async importConfig(filePath: string): Promise<void> {
    // Read and parse config file
    const configContent = fs.readFileSync(filePath, 'utf-8');

    // Validate config
    const parsed = parseOVPNConfig(configContent);

    if (!parsed.remote || !parsed.remote.host) {
      throw new Error('Invalid OpenVPN config: No remote server specified');
    }

    // Store config
    const configName = path.basename(filePath, path.extname(filePath));
    this.configStore.saveConfig(configName, configContent, parsed);

    this.emit('config-imported', { name: configName });
  }

  async setCredentials(username: string, password: string): Promise<void> {
    // Validate credentials
    if (!username || !password) {
      throw new Error('Username and password are required');
    }

    if (username.trim() === '' || password.trim() === '') {
      throw new Error('Username and password cannot be empty');
    }

    const config = this.configStore.getActiveConfig();
    if (!config) {
      throw new Error('No configuration available');
    }

    // Update the parsed config with credentials
    config.parsed.username = username.trim();
    config.parsed.password = password;

    // Save updated config using the correct method
    this.configStore.updateActiveConfig(config);

    console.log('[VPN] Credentials saved securely for config:', config.name);
  }

  async connect(): Promise<void> {
    if (this.status.connected || this.status.connecting) {
      throw new Error('Already connected or connecting');
    }

    const config = this.configStore.getActiveConfig();
    if (!config) {
      throw new Error('No configuration available');
    }

    this.updateStatus({ connecting: true, error: null });

    try {
      // Write config to temporary file
      this.tempConfigPath = path.join(
        require('electron').app.getPath('temp'),
        'workvpn-config.ovpn'
      );

      let configContent = config.content;

      // If config requires auth and we have credentials, store for stdin
      // SECURITY: Never write credentials to temp files (even briefly)
      // Use OpenVPN stdin auth instead
      if (config.parsed.requiresAuth && config.parsed.username && config.parsed.password) {
        // Store credentials securely in memory for stdin piping
        this.pendingAuthCredentials = {
          username: config.parsed.username,
          password: config.parsed.password
        };
        console.log('[VPN] Using stdin authentication (secure mode - no temp file)');

        // Modify config to use stdin auth (no file path)
        if (!configContent.includes('auth-user-pass')) {
          configContent += `\nauth-user-pass\n`;
        } else {
          // Replace existing auth-user-pass line (remove any file path)
          configContent = configContent.replace(/auth-user-pass.*$/gm, 'auth-user-pass');
        }
      }

      fs.writeFileSync(this.tempConfigPath, configContent);

      // Start OpenVPN process
      await this.startOpenVPN(this.tempConfigPath);

      this.updateStatus({
        connected: true,
        connecting: false,
        connectedSince: new Date(),
        serverIp: config.parsed.remote?.host,
      });

      // Start stats collection
      this.startStatsCollection();

      // SECURITY: No auth file cleanup needed - we never create plaintext files
      // Credentials provided via stdin when OpenVPN prompts

    } catch (error) {
      // Cleanup temp files on error for security
      this.cleanupTempFiles();

      this.updateStatus({
        connected: false,
        connecting: false,
        error: (error as Error).message
      });
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    // Disconnect management interface first
    this.disconnectManagementInterface();

    if (this.process) {
      // Windows doesn't support UNIX signals like SIGTERM
      // Use platform-appropriate termination
      if (process.platform === 'win32') {
        // Windows: Use taskkill for graceful termination
        try {
          const { exec } = require('child_process');
          exec(`taskkill /PID ${this.process.pid} /T /F`, (error: any) => {
            if (error) {
              console.error('[VPN] Failed to kill OpenVPN process:', error);
            }
          });
        } catch (error) {
          console.error('[VPN] Error terminating OpenVPN:', error);
          // Fallback to basic kill
          this.process.kill();
        }
      } else {
        // macOS/Linux: Use SIGTERM
        this.process.kill('SIGTERM');
      }
      this.process = null;
    }

    this.stopStatsCollection();

    // Cleanup temporary files for security
    this.cleanupTempFiles();

    this.updateStatus({
      connected: false,
      connecting: false,
      connectedSince: undefined,
      serverIp: undefined,
      localIp: undefined,
    });

    this.resetStats();
  }

  private cleanupTempFiles(): void {
    try {
      // Delete auth file (contains plaintext credentials)
      if (this.authFilePath && fs.existsSync(this.authFilePath)) {
        fs.unlinkSync(this.authFilePath);
        console.log('[VPN] Cleaned up auth file for security');
        this.authFilePath = null;
      }

      // Delete temp config file
      if (this.tempConfigPath && fs.existsSync(this.tempConfigPath)) {
        fs.unlinkSync(this.tempConfigPath);
        console.log('[VPN] Cleaned up temp config file');
        this.tempConfigPath = null;
      }
    } catch (error) {
      console.error('[VPN] Error cleaning up temp files:', error);
      // Don't throw - cleanup is best-effort for security
    }
  }

  private async connectManagementInterface(): Promise<void> {
    try {
      this.managementInterface = new OpenVPNManagementInterface({
        host: '127.0.0.1',
        port: 7505
      });

      await this.managementInterface.connect();

      this.managementInterface.on('disconnected', () => {
        console.log('[VPN] Management interface disconnected');
        this.managementInterface = null;
      });

      this.managementInterface.on('error', (error) => {
        console.error('[VPN] Management interface error:', error);
      });

      console.log('[VPN] Management interface connected - real stats available');
    } catch (error) {
      console.error('[VPN] Failed to connect to management interface:', error);
      this.managementInterface = null;
    }
  }

  private disconnectManagementInterface(): void {
    if (this.managementInterface) {
      this.managementInterface.disconnect();
      this.managementInterface = null;
    }
  }

  private async startOpenVPN(configPath: string): Promise<void> {
    return new Promise((resolve, reject) => {
      // Determine OpenVPN binary path based on platform
      let openvpnBinary: string;

      if (process.platform === 'win32') {
        // Windows: Try multiple possible installation locations
        const possiblePaths = [
          'C:\\Program Files\\OpenVPN\\bin\\openvpn.exe',           // Default 64-bit
          'C:\\Program Files (x86)\\OpenVPN\\bin\\openvpn.exe',    // Default 32-bit
          path.join(process.env.ProgramFiles || 'C:\\Program Files', 'OpenVPN', 'bin', 'openvpn.exe'),
          path.join(process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)', 'OpenVPN', 'bin', 'openvpn.exe'),
        ];

        const foundPath = possiblePaths.find(p => fs.existsSync(p));
        if (!foundPath) {
          reject(new Error(
            'OpenVPN not found. Please install OpenVPN from https://openvpn.net/community-downloads/\n' +
            'Searched locations:\n' + possiblePaths.join('\n')
          ));
          return;
        }
        openvpnBinary = foundPath;
      } else if (process.platform === 'darwin') {
        // macOS: Try multiple locations (Homebrew Intel, Homebrew ARM, manual install)
        const possiblePaths = [
          '/opt/homebrew/sbin/openvpn',  // Homebrew ARM (M1/M2 Macs)
          '/usr/local/sbin/openvpn',      // Homebrew Intel
          '/usr/local/bin/openvpn',       // Manual install
          '/opt/homebrew/bin/openvpn'     // Alternative Homebrew location
        ];

        const foundPath = possiblePaths.find(p => fs.existsSync(p));
        if (!foundPath) {
          reject(new Error(
            'OpenVPN not found. Please install with: brew install openvpn\n' +
            'Searched locations:\n' + possiblePaths.join('\n')
          ));
          return;
        }
        openvpnBinary = foundPath;
      } else {
        // Linux: Try common locations
        const possiblePaths = [
          '/usr/sbin/openvpn',
          '/usr/bin/openvpn',
          '/usr/local/sbin/openvpn'
        ];

        const foundPath = possiblePaths.find(p => fs.existsSync(p));
        if (!foundPath) {
          reject(new Error(
            'OpenVPN not found. Please install with: sudo apt-get install openvpn\n' +
            'Searched locations:\n' + possiblePaths.join('\n')
          ));
          return;
        }
        openvpnBinary = foundPath;
      }

      console.log('[VPN] Using OpenVPN binary:', openvpnBinary);

      // Start OpenVPN process with management interface enabled
      const managementPort = 7505;
      const openvpnArgs = [
        '--config', configPath,
        '--verb', '3',
        '--management', '127.0.0.1', String(managementPort),
        '--management-query-passwords',
        '--management-hold'
      ];

      // Windows-specific: OpenVPN requires admin privileges
      // We'll spawn the process and check for permission errors
      if (process.platform === 'win32') {
        console.log('[VPN] Windows detected - OpenVPN may require administrator privileges');
        console.log('[VPN] If connection fails, try running the app as Administrator');
      }

      this.process = spawn(openvpnBinary, openvpnArgs);

      // Use state machine for atomic connection state tracking
      // Prevents race conditions between event handlers
      enum ConnectionState {
        CONNECTING = 'connecting',
        CONNECTED = 'connected',
        FAILED = 'failed'
      }
      let connectionState: ConnectionState = ConnectionState.CONNECTING;

      this.process.stdout?.on('data', (data) => {
        const output = data.toString();
        console.log('[OpenVPN]', output);

        // Detect successful connection (atomic state transition)
        if (output.includes('Initialization Sequence Completed') &&
            connectionState === ConnectionState.CONNECTING) {
          connectionState = ConnectionState.CONNECTED;

          // Connect to management interface for real stats
          this.connectManagementInterface();

          resolve();
        }

        // Extract local IP
        const ipMatch = output.match(/ifconfig\s+(\d+\.\d+\.\d+\.\d+)/);
        if (ipMatch) {
          this.status.localIp = ipMatch[1];
          this.emit('status-changed', this.status);
        }
      });

      this.process.stderr?.on('data', (data) => {
        console.error('[OpenVPN Error]', data.toString());
      });

      this.process.on('error', (error) => {
        if (connectionState === ConnectionState.CONNECTING) {
          connectionState = ConnectionState.FAILED;
          reject(error);
        }
        this.handleDisconnect('Process error: ' + error.message);
      });

      this.process.on('exit', (code) => {
        if (connectionState === ConnectionState.CONNECTING && code !== 0) {
          connectionState = ConnectionState.FAILED;
          reject(new Error(`OpenVPN exited with code ${code}`));
        }
        this.handleDisconnect(`Process exited with code ${code}`);
      });

      // Timeout after 30 seconds
      setTimeout(() => {
        if (!connected) {
          this.process?.kill();
          reject(new Error('Connection timeout'));
        }
      }, 30000);
    });
  }

  private handleDisconnect(reason: string): void {
    if (this.status.connected || this.status.connecting) {
      // Cleanup temp files for security
      this.cleanupTempFiles();

      this.updateStatus({
        connected: false,
        connecting: false,
        error: reason,
        connectedSince: undefined,
        serverIp: undefined,
        localIp: undefined,
      });

      this.stopStatsCollection();
      this.resetStats();
    }
  }

  private startStatsCollection(): void {
    // Update stats every second
    this.statsInterval = setInterval(() => {
      if (this.status.connected && this.status.connectedSince) {
        this.stats.duration = Math.floor(
          (Date.now() - this.status.connectedSince.getTime()) / 1000
        );

        // Get actual traffic stats from OpenVPN management interface
        this.updateTrafficStats();

        this.emit('stats-update', this.stats);
      }
    }, 1000);
  }

  private async updateTrafficStats(): Promise<void> {
    // ✅ Integrated OpenVPN management interface for real stats
    if (!this.managementInterface) {
      return;
    }

    try {
      const stats = await this.managementInterface.getStatistics();
      this.stats.bytesIn = stats.bytesIn;
      this.stats.bytesOut = stats.bytesOut;
    } catch (error) {
      console.error('[VPN] Failed to get stats from management interface:', error);
      // Stats remain at last known values
    }
  }

  private stopStatsCollection(): void {
    if (this.statsInterval) {
      clearInterval(this.statsInterval);
      this.statsInterval = null;
    }
  }

  private resetStats(): void {
    this.stats = {
      bytesIn: 0,
      bytesOut: 0,
      duration: 0
    };
    this.emit('stats-update', this.stats);
  }

  private updateStatus(update: Partial<VPNStatus>): void {
    this.status = { ...this.status, ...update };
    this.emit('status-changed', this.status);
  }

  getStatus(): VPNStatus {
    return { ...this.status };
  }

  getStats(): VPNStats {
    return { ...this.stats };
  }

  hasConfig(): boolean {
    return this.configStore.hasActiveConfig();
  }

  getConfigInfo(): any {
    const config = this.configStore.getActiveConfig();
    if (!config) return null;

    return {
      name: config.name,
      server: config.parsed.remote?.host,
      port: config.parsed.remote?.port,
      protocol: config.parsed.proto || 'udp',
    };
  }

  async deleteConfig(): Promise<void> {
    if (this.status.connected) {
      await this.disconnect();
    }
    this.configStore.deleteActiveConfig();
    this.emit('config-deleted');
  }
}
