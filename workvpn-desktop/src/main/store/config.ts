import Store from 'electron-store';
import { ParsedOVPNConfig } from '../vpn/parser';

interface StoredConfig {
  name: string;
  content: string;
  parsed: ParsedOVPNConfig;
  importedAt: string;
}

interface StoreSchema {
  activeConfig: StoredConfig | null;
  configs: Record<string, StoredConfig>;
  autoConnect: boolean;
  autoStart: boolean;
  killSwitch: boolean;
}

export class ConfigStore {
  private store: Store<StoreSchema>;

  constructor() {
    this.store = new Store<StoreSchema>({
      name: 'workvpn-config',
      defaults: {
        activeConfig: null,
        configs: {},
        autoConnect: false,
        autoStart: false,
        killSwitch: false,
      },
      encryptionKey: 'workvpn-encryption-key-change-in-production',
    });
  }

  saveConfig(name: string, content: string, parsed: ParsedOVPNConfig): void {
    const config: StoredConfig = {
      name,
      content,
      parsed,
      importedAt: new Date().toISOString(),
    };

    // Save to configs map
    const configs = this.store.get('configs');
    configs[name] = config;
    this.store.set('configs', configs);

    // Set as active config
    this.store.set('activeConfig', config);
  }

  getActiveConfig(): StoredConfig | null {
    return this.store.get('activeConfig');
  }

  hasActiveConfig(): boolean {
    return this.store.get('activeConfig') !== null;
  }

  deleteActiveConfig(): void {
    const activeConfig = this.store.get('activeConfig');
    if (activeConfig) {
      const configs = this.store.get('configs');
      delete configs[activeConfig.name];
      this.store.set('configs', configs);
      this.store.set('activeConfig', null);
    }
  }

  getAllConfigs(): StoredConfig[] {
    const configs = this.store.get('configs');
    return Object.values(configs);
  }

  setActiveConfig(name: string): boolean {
    const configs = this.store.get('configs');
    const config = configs[name];

    if (config) {
      this.store.set('activeConfig', config);
      return true;
    }

    return false;
  }

  updateActiveConfig(config: StoredConfig): void {
    // Update the active config directly (used for credential updates)
    this.store.set('activeConfig', config);

    // Also update in configs map to keep them in sync
    const configs = this.store.get('configs');
    configs[config.name] = config;
    this.store.set('configs', configs);
  }

  get<K extends keyof StoreSchema>(key: K): StoreSchema[K] {
    return this.store.get(key);
  }

  set<K extends keyof StoreSchema>(key: K, value: StoreSchema[K]): void {
    this.store.set(key, value);
  }

  clear(): void {
    this.store.clear();
  }
}
