export interface ParsedOVPNConfig {
  remote?: {
    host: string;
    port: number;
  };
  proto?: string;
  dev?: string;
  ca?: string;
  cert?: string;
  key?: string;
  tlsAuth?: string;
  cipher?: string;
  auth?: string;
  keyDirection?: number;
  [key: string]: any;
}

export function parseOVPNConfig(content: string): ParsedOVPNConfig {
  const lines = content.split('\n');
  const config: ParsedOVPNConfig = {};

  let inlineBlockType: string | null = null;
  let inlineBlockContent: string[] = [];

  for (const line of lines) {
    const trimmed = line.trim();

    // Skip empty lines and comments
    if (!trimmed || trimmed.startsWith('#') || trimmed.startsWith(';')) {
      continue;
    }

    // Handle inline blocks (e.g., <ca>, <cert>, <key>)
    if (trimmed.startsWith('<')) {
      const match = trimmed.match(/<(\/?)([\w-]+)>/);
      if (match) {
        const isClosing = match[1] === '/';
        const blockType = match[2];

        if (isClosing) {
          // End of inline block
          if (inlineBlockType === blockType) {
            config[inlineBlockType] = inlineBlockContent.join('\n');
            inlineBlockType = null;
            inlineBlockContent = [];
          }
        } else {
          // Start of inline block
          inlineBlockType = blockType;
          inlineBlockContent = [];
        }
      }
      continue;
    }

    // If we're in an inline block, collect the content
    if (inlineBlockType) {
      inlineBlockContent.push(line);
      continue;
    }

    // Parse key-value pairs
    const parts = trimmed.split(/\s+/);
    const key = parts[0];
    const values = parts.slice(1);

    switch (key) {
      case 'remote':
        config.remote = {
          host: values[0],
          port: parseInt(values[1]) || 1194
        };
        break;

      case 'proto':
        config.proto = values[0];
        break;

      case 'dev':
        config.dev = values[0];
        break;

      case 'cipher':
        config.cipher = values[0];
        break;

      case 'auth':
        config.auth = values[0];
        break;

      case 'key-direction':
        config.keyDirection = parseInt(values[0]);
        break;

      default:
        // Store other options
        if (values.length > 0) {
          config[key] = values.length === 1 ? values[0] : values;
        } else {
          config[key] = true;
        }
    }
  }

  return config;
}

export function validateOVPNConfig(config: ParsedOVPNConfig): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  // Check for required fields
  if (!config.remote || !config.remote.host) {
    errors.push('Missing remote server address');
  }

  if (!config.ca && !config['<ca>']) {
    errors.push('Missing CA certificate');
  }

  // Warn about common issues
  if (!config.dev) {
    errors.push('No device type specified (should be tun or tap)');
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

export function generateOVPNConfig(config: ParsedOVPNConfig): string {
  const lines: string[] = [];

  // Add basic directives
  lines.push('client');
  lines.push(`dev ${config.dev || 'tun'}`);
  lines.push(`proto ${config.proto || 'udp'}`);

  if (config.remote) {
    lines.push(`remote ${config.remote.host} ${config.remote.port || 1194}`);
  }

  lines.push('resolv-retry infinite');
  lines.push('nobind');
  lines.push('persist-key');
  lines.push('persist-tun');

  if (config.cipher) {
    lines.push(`cipher ${config.cipher}`);
  }

  if (config.auth) {
    lines.push(`auth ${config.auth}`);
  }

  lines.push('verb 3');

  // Add inline blocks
  if (config.ca) {
    lines.push('<ca>');
    lines.push(config.ca);
    lines.push('</ca>');
  }

  if (config.cert) {
    lines.push('<cert>');
    lines.push(config.cert);
    lines.push('</cert>');
  }

  if (config.key) {
    lines.push('<key>');
    lines.push(config.key);
    lines.push('</key>');
  }

  if (config.tlsAuth) {
    lines.push('<tls-auth>');
    lines.push(config.tlsAuth);
    lines.push('</tls-auth>');
  }

  return lines.join('\n');
}
