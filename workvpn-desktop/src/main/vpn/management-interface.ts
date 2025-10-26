import * as net from 'net';
import { EventEmitter } from 'events';

/**
 * OpenVPN Management Interface Client
 *
 * Connects to OpenVPN's management interface to get real-time stats
 * and control the VPN connection.
 *
 * OpenVPN management interface provides:
 * - Real traffic statistics (bytes in/out)
 * - Connection state
 * - Client list
 * - Log messages
 * - Control commands (disconnect, restart, etc.)
 */

export interface VPNStatistics {
  bytesIn: number;
  bytesOut: number;
  timestamp: Date;
}

export interface ManagementConfig {
  host: string;
  port: number;
  password?: string;
}

export class OpenVPNManagementInterface extends EventEmitter {
  private socket: net.Socket | null = null;
  private config: ManagementConfig;
  private isConnected = false;
  private statsInterval: NodeJS.Timeout | null = null;

  constructor(config: ManagementConfig = { host: '127.0.0.1', port: 7505 }) {
    super();
    this.config = config;
  }

  /**
   * Connect to OpenVPN management interface
   */
  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.socket = new net.Socket();

      this.socket.connect(this.config.port, this.config.host, () => {
        console.log('[MGMT] Connected to OpenVPN management interface');
        this.isConnected = true;
        this.emit('connected');

        // Release OpenVPN from hold state (required when --management-hold is set)
        this.sendCommand('hold release');
        console.log('[MGMT] Sent hold release command');

        // Authenticate if password is set
        if (this.config.password) {
          this.sendCommand(`password ${this.config.password}`);
        }

        // Start collecting stats
        this.startStatsCollection();

        resolve();
      });

      this.socket.on('data', (data) => {
        this.handleData(data.toString());
      });

      this.socket.on('error', (error) => {
        console.error('[MGMT] Error:', error);
        this.emit('error', error);
        reject(error);
      });

      this.socket.on('close', () => {
        console.log('[MGMT] Connection closed');
        this.isConnected = false;
        this.stopStatsCollection();
        this.emit('disconnected');
      });
    });
  }

  /**
   * Disconnect from management interface
   */
  disconnect(): void {
    this.stopStatsCollection();

    if (this.socket) {
      this.socket.destroy();
      this.socket = null;
    }

    this.isConnected = false;
  }

  /**
   * Send command to OpenVPN
   */
  private sendCommand(command: string): void {
    if (!this.socket || !this.isConnected) {
      console.error('[MGMT] Not connected');
      return;
    }

    this.socket.write(command + '\n');
  }

  /**
   * Get current VPN statistics
   */
  async getStatistics(): Promise<VPNStatistics> {
    return new Promise((resolve) => {
      const handler = (data: string) => {
        // Parse BYTECOUNT response
        // Format: >BYTECOUNT:bytes_in,bytes_out
        const match = data.match(/>BYTECOUNT:(\d+),(\d+)/);
        if (match) {
          resolve({
            bytesIn: parseInt(match[1]),
            bytesOut: parseInt(match[2]),
            timestamp: new Date()
          });
        }
      };

      this.once('data', handler);
      this.sendCommand('bytecount');

      // Timeout after 5 seconds
      setTimeout(() => {
        this.off('data', handler);
        resolve({ bytesIn: 0, bytesOut: 0, timestamp: new Date() });
      }, 5000);
    });
  }

  /**
   * Get connection state
   */
  async getState(): Promise<string> {
    return new Promise((resolve) => {
      const handler = (data: string) => {
        // Parse STATE response
        // Format: >STATE:timestamp,state,description,local_ip,remote_ip
        const match = data.match(/>STATE:.*?,(\w+)/);
        if (match) {
          resolve(match[1]);
        }
      };

      this.once('data', handler);
      this.sendCommand('state');

      setTimeout(() => {
        this.off('data', handler);
        resolve('UNKNOWN');
      }, 5000);
    });
  }

  /**
   * Get OpenVPN version
   */
  async getVersion(): Promise<string> {
    return new Promise((resolve) => {
      const handler = (data: string) => {
        if (data.includes('OpenVPN')) {
          const version = data.match(/OpenVPN ([\d.]+)/)?.[1] || 'unknown';
          resolve(version);
        }
      };

      this.once('data', handler);
      this.sendCommand('version');

      setTimeout(() => {
        this.off('data', handler);
        resolve('unknown');
      }, 5000);
    });
  }

  /**
   * Handle incoming data from OpenVPN
   */
  private handleData(data: string): void {
    this.emit('data', data);

    // Parse real-time updates
    if (data.includes('>BYTECOUNT:')) {
      const match = data.match(/>BYTECOUNT:(\d+),(\d+)/);
      if (match) {
        this.emit('stats', {
          bytesIn: parseInt(match[1]),
          bytesOut: parseInt(match[2]),
          timestamp: new Date()
        });
      }
    }

    if (data.includes('>STATE:')) {
      const match = data.match(/>STATE:.*?,(\w+)/);
      if (match) {
        this.emit('state-change', match[1]);
      }
    }

    if (data.includes('>LOG:')) {
      this.emit('log', data);
    }
  }

  /**
   * Start collecting statistics periodically
   */
  private startStatsCollection(): void {
    // Enable real-time byte count updates
    this.sendCommand('bytecount 1'); // Update every 1 second

    // Also enable state updates
    this.sendCommand('state on');

    // Poll for stats every 2 seconds as backup
    this.statsInterval = setInterval(() => {
      if (this.isConnected) {
        this.sendCommand('bytecount');
        this.sendCommand('state');
      }
    }, 2000);
  }

  /**
   * Stop collecting statistics
   */
  private stopStatsCollection(): void {
    if (this.statsInterval) {
      clearInterval(this.statsInterval);
      this.statsInterval = null;
    }
  }

  /**
   * Check if connected to management interface
   */
  isManagementConnected(): boolean {
    return this.isConnected;
  }
}

/**
 * Usage in VPN Manager:
 *
 * ```typescript
 * // In vpn/manager.ts
 *
 * import { OpenVPNManagementInterface } from './management-interface';
 *
 * class VPNManager {
 *   private mgmt: OpenVPNManagementInterface;
 *
 *   async connect() {
 *     // Start OpenVPN process...
 *
 *     // Connect to management interface
 *     this.mgmt = new OpenVPNManagementInterface({
 *       host: '127.0.0.1',
 *       port: 7505
 *     });
 *
 *     await this.mgmt.connect();
 *
 *     // Listen for real-time stats
 *     this.mgmt.on('stats', (stats) => {
 *       this.stats.bytesIn = stats.bytesIn;
 *       this.stats.bytesOut = stats.bytesOut;
 *       this.emit('stats-update', this.stats);
 *     });
 *
 *     // Listen for state changes
 *     this.mgmt.on('state-change', (state) => {
 *       console.log('VPN state:', state);
 *     });
 *   }
 *
 *   async disconnect() {
 *     this.mgmt.disconnect();
 *     // Stop OpenVPN process...
 *   }
 * }
 * ```
 *
 * To enable management interface, add to .ovpn config:
 * ```
 * management 127.0.0.1 7505
 * management-hold
 * ```
 */
