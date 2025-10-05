/**
 * WorkVPN Desktop - Integration Tests
 *
 * Comprehensive test suite for Platform 1 (Desktop Electron App)
 * Tests all features that don't require actual VPN connection
 */

const fs = require('fs');
const path = require('path');

// ANSI colors for output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

// Test results tracking
let totalTests = 0;
let passedTests = 0;
let failedTests = 0;
const failedTestDetails = [];

// Helper functions
function assert(condition, message) {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  ${colors.green}✓${colors.reset} ${message}`);
    return true;
  } else {
    failedTests++;
    const error = new Error(message);
    failedTestDetails.push({ message, stack: error.stack });
    console.log(`  ${colors.red}✗${colors.reset} ${message}`);
    return false;
  }
}

function testSection(name) {
  console.log(`\n${colors.cyan}━━━ ${name} ━━━${colors.reset}`);
}

function testGroup(name) {
  console.log(`\n${colors.blue}▶ ${name}${colors.reset}`);
}

// Import modules to test
const parserPath = path.join(__dirname, '../dist/main/vpn/parser.js');
const configStorePath = path.join(__dirname, '../dist/main/store/config.js');

// Check if compiled files exist
function checkCompiledFiles() {
  testSection('Pre-flight Checks');

  const requiredFiles = [
    'dist/main/index.js',
    'dist/main/window.js',
    'dist/main/tray.js',
    'dist/main/vpn/manager.js',
    'dist/main/vpn/parser.js',
    'dist/main/store/config.js',
    'dist/preload/index.js',
    'dist/renderer/app.js',
    'dist/renderer/index.html',
    'dist/renderer/styles.css',
    'assets/icon.png',
    'assets/icon.ico',
    'assets/icon.icns'
  ];

  testGroup('File Structure');

  requiredFiles.forEach(file => {
    const fullPath = path.join(__dirname, '..', file);
    assert(fs.existsSync(fullPath), `${file} exists`);
  });
}

// Test .ovpn config parser
function testConfigParser() {
  testSection('.ovpn Config Parser Tests');

  // Load parser module
  const { parseOVPNConfig, validateOVPNConfig, generateOVPNConfig } = require(parserPath);

  testGroup('Basic Parsing');

  // Test 1: Parse basic config
  const basicConfig = `
client
dev tun
proto udp
remote vpn.example.com 1194
cipher AES-256-CBC
auth SHA256
`;

  const parsed1 = parseOVPNConfig(basicConfig);
  assert(parsed1.remote && parsed1.remote.host === 'vpn.example.com', 'Parses remote host');
  assert(parsed1.remote && parsed1.remote.port === 1194, 'Parses remote port');
  assert(parsed1.proto === 'udp', 'Parses protocol');
  assert(parsed1.dev === 'tun', 'Parses device type');
  assert(parsed1.cipher === 'AES-256-CBC', 'Parses cipher');
  assert(parsed1.auth === 'SHA256', 'Parses auth');

  testGroup('Inline Certificate Blocks');

  // Test 2: Parse inline CA certificate
  const configWithCA = `
remote vpn.test.com 1194
<ca>
-----BEGIN CERTIFICATE-----
MIIDTEST123
-----END CERTIFICATE-----
</ca>
`;

  const parsed2 = parseOVPNConfig(configWithCA);
  assert(parsed2.ca && parsed2.ca.includes('-----BEGIN CERTIFICATE-----'), 'Parses inline CA certificate');
  assert(parsed2.ca && parsed2.ca.includes('MIIDTEST123'), 'Extracts CA certificate content');

  // Test 3: Parse multiple inline blocks
  const configWithMultiple = `
remote vpn.test.com 443
proto tcp
<ca>
CA CERT HERE
</ca>
<cert>
CLIENT CERT HERE
</cert>
<key>
PRIVATE KEY HERE
</key>
<tls-auth>
TLS AUTH KEY HERE
</tls-auth>
`;

  const parsed3 = parseOVPNConfig(configWithMultiple);
  assert(parsed3.ca && parsed3.ca.includes('CA CERT HERE'), 'Parses CA block');
  assert(parsed3.cert && parsed3.cert.includes('CLIENT CERT HERE'), 'Parses cert block');
  assert(parsed3.key && parsed3.key.includes('PRIVATE KEY HERE'), 'Parses key block');
  assert(parsed3['tls-auth'] && parsed3['tls-auth'].includes('TLS AUTH KEY HERE'), 'Parses tls-auth block');

  testGroup('Comment and Empty Line Handling');

  // Test 4: Skip comments and empty lines
  const configWithComments = `
# This is a comment
client
; This is also a comment
dev tun

# Another comment
remote vpn.test.com 1194
`;

  const parsed4 = parseOVPNConfig(configWithComments);
  assert(parsed4.client === true, 'Parses client directive');
  assert(parsed4.dev === 'tun', 'Skips comments correctly');
  assert(parsed4.remote && parsed4.remote.host === 'vpn.test.com', 'Skips empty lines correctly');

  testGroup('Key-Direction Parsing');

  // Test 5: Parse key-direction
  const configWithKeyDir = `
remote vpn.test.com 1194
key-direction 1
`;

  const parsed5 = parseOVPNConfig(configWithKeyDir);
  assert(parsed5.keyDirection === 1, 'Parses key-direction as integer');

  testGroup('Multi-value Options');

  // Test 6: Store other options
  const configWithOptions = `
remote vpn.test.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
verb 3
`;

  const parsed6 = parseOVPNConfig(configWithOptions);
  assert(parsed6['resolv-retry'] === 'infinite', 'Parses option with value');
  assert(parsed6.nobind === true, 'Parses boolean option');
  assert(parsed6['persist-key'] === true, 'Parses persist-key');
  assert(parsed6['persist-tun'] === true, 'Parses persist-tun');
  assert(parsed6.verb === '3', 'Parses verb level');
}

// Test config validation
function testConfigValidation() {
  testSection('Config Validation Tests');

  const { parseOVPNConfig, validateOVPNConfig } = require(parserPath);

  testGroup('Valid Configs');

  // Test 1: Valid config with all required fields
  const validConfig = parseOVPNConfig(`
remote vpn.test.com 1194
<ca>
-----BEGIN CERTIFICATE-----
TEST
-----END CERTIFICATE-----
</ca>
dev tun
`);

  const validation1 = validateOVPNConfig(validConfig);
  assert(validation1.valid === true, 'Validates config with all required fields');
  assert(validation1.errors.length === 0, 'No errors for valid config');

  testGroup('Invalid Configs');

  // Test 2: Missing remote
  const noRemote = parseOVPNConfig(`
<ca>
-----BEGIN CERTIFICATE-----
TEST
-----END CERTIFICATE-----
</ca>
`);

  const validation2 = validateOVPNConfig(noRemote);
  assert(validation2.valid === false, 'Rejects config without remote');
  assert(validation2.errors.some(e => e.includes('remote')), 'Error mentions missing remote');

  // Test 3: Missing CA
  const noCA = parseOVPNConfig(`
remote vpn.test.com 1194
dev tun
`);

  const validation3 = validateOVPNConfig(noCA);
  assert(validation3.valid === false, 'Rejects config without CA');
  assert(validation3.errors.some(e => e.includes('CA')), 'Error mentions missing CA');

  // Test 4: Missing device type
  const noDev = parseOVPNConfig(`
remote vpn.test.com 1194
<ca>
TEST CERT
</ca>
`);

  const validation4 = validateOVPNConfig(noDev);
  assert(validation4.valid === false, 'Warns about missing device type');
  assert(validation4.errors.some(e => e.includes('device')), 'Error mentions device type');
}

// Test config generation
function testConfigGeneration() {
  testSection('Config Generation Tests');

  const { parseOVPNConfig, generateOVPNConfig } = require(parserPath);

  testGroup('Generate from Parsed Config');

  // Test 1: Generate basic config
  const originalConfig = {
    remote: { host: 'vpn.test.com', port: 1194 },
    proto: 'udp',
    dev: 'tun',
    cipher: 'AES-256-CBC',
    auth: 'SHA256',
    ca: '-----BEGIN CERTIFICATE-----\nTEST\n-----END CERTIFICATE-----'
  };

  const generated = generateOVPNConfig(originalConfig);
  assert(generated.includes('remote vpn.test.com 1194'), 'Generates remote directive');
  assert(generated.includes('proto udp'), 'Generates proto directive');
  assert(generated.includes('dev tun'), 'Generates dev directive');
  assert(generated.includes('cipher AES-256-CBC'), 'Generates cipher directive');
  assert(generated.includes('auth SHA256'), 'Generates auth directive');
  assert(generated.includes('<ca>'), 'Generates CA block opening');
  assert(generated.includes('</ca>'), 'Generates CA block closing');
  assert(generated.includes('client'), 'Includes client directive');

  testGroup('Round-trip Parsing');

  // Test 2: Parse → Generate → Parse should be identical
  const originalParsed = parseOVPNConfig(`
client
dev tun
proto udp
remote vpn.test.com 1194
cipher AES-256-CBC
auth SHA256
<ca>
TEST CERT
</ca>
`);

  const generatedConfig = generateOVPNConfig(originalParsed);
  const reparsed = parseOVPNConfig(generatedConfig);

  assert(reparsed.remote.host === originalParsed.remote.host, 'Round-trip preserves remote host');
  assert(reparsed.remote.port === originalParsed.remote.port, 'Round-trip preserves remote port');
  assert(reparsed.proto === originalParsed.proto, 'Round-trip preserves protocol');
  assert(reparsed.dev === originalParsed.dev, 'Round-trip preserves device');
  assert(reparsed.cipher === originalParsed.cipher, 'Round-trip preserves cipher');
  assert(reparsed.ca === originalParsed.ca, 'Round-trip preserves CA');
}

// Test file system operations
function testFileOperations() {
  testSection('File System Tests');

  testGroup('Test Config File');

  const testConfigPath = path.join(__dirname, '../test-config.ovpn');
  assert(fs.existsSync(testConfigPath), 'test-config.ovpn exists');

  if (fs.existsSync(testConfigPath)) {
    const content = fs.readFileSync(testConfigPath, 'utf-8');
    assert(content.length > 0, 'test-config.ovpn has content');
    assert(content.includes('remote'), 'test-config.ovpn has remote directive');
    assert(content.includes('<ca>'), 'test-config.ovpn has CA certificate');
  }

  testGroup('Package Configuration');

  const packagePath = path.join(__dirname, '../package.json');
  const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf-8'));

  assert(packageJson.name === 'workvpn-desktop', 'Package name is correct');
  assert(packageJson.version === '1.0.0', 'Package version is set');
  assert(packageJson.main === 'dist/main.js', 'Main entry point is correct');
  assert(packageJson.scripts.build, 'Build script exists');
  assert(packageJson.scripts.start, 'Start script exists');
  assert(packageJson.scripts.make, 'Make script exists');

  testGroup('TypeScript Configuration');

  const tsconfigPath = path.join(__dirname, '../tsconfig.json');
  const tsconfig = JSON.parse(fs.readFileSync(tsconfigPath, 'utf-8'));

  assert(tsconfig.compilerOptions.target === 'ES2020', 'TypeScript target is ES2020');
  assert(tsconfig.compilerOptions.module === 'commonjs', 'Module system is commonjs');
  assert(tsconfig.compilerOptions.strict === true, 'Strict mode is enabled');
  assert(tsconfig.compilerOptions.outDir === './dist', 'Output directory is dist');
}

// Test renderer files
function testRendererFiles() {
  testSection('Renderer (UI) Tests');

  testGroup('HTML Structure');

  const htmlPath = path.join(__dirname, '../dist/renderer/index.html');
  const html = fs.readFileSync(htmlPath, 'utf-8');

  assert(html.includes('<!DOCTYPE html>'), 'Has HTML5 doctype');
  assert(html.includes('Content-Security-Policy'), 'Has CSP meta tag');
  assert(html.includes('WorkVPN'), 'Has title');
  assert(html.includes('styles.css'), 'Links to styles.css');
  assert(html.includes('app.js'), 'Links to app.js');

  // Check for required UI elements
  assert(html.includes('id="no-config-state"'), 'Has no-config-state element');
  assert(html.includes('id="vpn-state"'), 'Has vpn-state element');
  assert(html.includes('id="connecting-state"'), 'Has connecting-state element');
  assert(html.includes('id="error-state"'), 'Has error-state element');
  assert(html.includes('id="import-btn"'), 'Has import button');
  assert(html.includes('id="connect-btn"'), 'Has connect button');
  assert(html.includes('id="disconnect-btn"'), 'Has disconnect button');
  assert(html.includes('id="auto-connect-check"'), 'Has auto-connect checkbox');
  assert(html.includes('id="auto-start-check"'), 'Has auto-start checkbox');
  assert(html.includes('id="kill-switch-check"'), 'Has kill-switch checkbox');

  testGroup('CSS Styling');

  const cssPath = path.join(__dirname, '../dist/renderer/styles.css');
  const css = fs.readFileSync(cssPath, 'utf-8');

  assert(css.includes('gradient'), 'Has gradient styling');
  assert(css.includes('.status-icon'), 'Has status icon styles');
  assert(css.includes('.connected'), 'Has connected state styles');
  assert(css.includes('.disconnected'), 'Has disconnected state styles');
  assert(css.includes('.loader'), 'Has loader animation');
  assert(css.includes('@keyframes'), 'Has CSS animations');

  testGroup('JavaScript Compilation');

  const jsPath = path.join(__dirname, '../dist/renderer/app.js');
  const js = fs.readFileSync(jsPath, 'utf-8');

  assert(js.includes('function'), 'Has compiled functions');
  assert(js.includes('updateUI'), 'Has updateUI function');
  assert(js.includes('handleConnect'), 'Has handleConnect function');
  assert(js.includes('handleDisconnect'), 'Has handleDisconnect function');
  assert(js.includes('handleImport'), 'Has handleImport function');
}

// Test asset files
function testAssets() {
  testSection('Asset Files Tests');

  testGroup('Icons');

  const assetsDir = path.join(__dirname, '../assets');

  // Check all icon formats
  const iconPng = path.join(assetsDir, 'icon.png');
  const iconIco = path.join(assetsDir, 'icon.ico');
  const iconIcns = path.join(assetsDir, 'icon.icns');
  const iconSvg = path.join(assetsDir, 'icon.svg');

  assert(fs.existsSync(iconPng), 'icon.png exists');
  assert(fs.existsSync(iconIco), 'icon.ico exists');
  assert(fs.existsSync(iconIcns), 'icon.icns exists');
  assert(fs.existsSync(iconSvg), 'icon.svg exists');

  // Check file sizes (should not be empty)
  if (fs.existsSync(iconPng)) {
    const stats = fs.statSync(iconPng);
    assert(stats.size > 1000, 'icon.png is reasonable size (>1KB)');
  }

  if (fs.existsSync(iconIco)) {
    const stats = fs.statSync(iconIco);
    assert(stats.size > 5000, 'icon.ico is reasonable size (>5KB)');
  }

  if (fs.existsSync(iconIcns)) {
    const stats = fs.statSync(iconIcns);
    assert(stats.size > 10000, 'icon.icns is reasonable size (>10KB)');
  }
}

// Test documentation
function testDocumentation() {
  testSection('Documentation Tests');

  testGroup('README');

  const readmePath = path.join(__dirname, '../README.md');
  const readme = fs.readFileSync(readmePath, 'utf-8');

  assert(readme.includes('WorkVPN'), 'README has project name');
  assert(readme.includes('Features'), 'README has features section');
  assert(readme.includes('Installation'), 'README has installation section');
  assert(readme.includes('Usage'), 'README has usage section');
  assert(readme.includes('OpenVPN'), 'README mentions OpenVPN');
  assert(readme.includes('npm install'), 'README has npm install command');
  assert(readme.includes('npm start'), 'README has npm start command');

  testGroup('Setup and Testing Guide');

  const setupPath = path.join(__dirname, '../SETUP_AND_TESTING.md');
  assert(fs.existsSync(setupPath), 'SETUP_AND_TESTING.md exists');

  const setup = fs.readFileSync(setupPath, 'utf-8');
  assert(setup.includes('Testing Checklist'), 'Has testing checklist');
  assert(setup.includes('Phase 1'), 'Has test phases');
  assert(setup.includes('brew install openvpn'), 'Has OpenVPN installation instructions');

  testGroup('Build Status');

  const buildStatusPath = path.join(__dirname, '../BUILD_STATUS.md');
  assert(fs.existsSync(buildStatusPath), 'BUILD_STATUS.md exists');

  const buildStatus = fs.readFileSync(buildStatusPath, 'utf-8');
  assert(buildStatus.includes('Platform 1'), 'Tracks Platform 1');
  assert(buildStatus.includes('Platform 2'), 'Tracks Platform 2');
  assert(buildStatus.includes('Platform 3'), 'Tracks Platform 3');
}

// Print final results
function printResults() {
  console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}`);
  console.log(`${colors.cyan}                    TEST RESULTS${colors.reset}`);
  console.log(`${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

  const passRate = ((passedTests / totalTests) * 100).toFixed(1);

  console.log(`Total Tests:  ${totalTests}`);
  console.log(`${colors.green}Passed:       ${passedTests}${colors.reset}`);
  console.log(`${colors.red}Failed:       ${failedTests}${colors.reset}`);
  console.log(`Pass Rate:    ${passRate}%\n`);

  if (failedTests > 0) {
    console.log(`${colors.red}━━━ Failed Tests Details ━━━${colors.reset}\n`);
    failedTestDetails.forEach((failure, index) => {
      console.log(`${index + 1}. ${failure.message}`);
    });
    console.log('');
  }

  if (passRate == 100) {
    console.log(`${colors.green}✓ ALL TESTS PASSED!${colors.reset}\n`);
    return 0;
  } else if (passRate >= 90) {
    console.log(`${colors.yellow}⚠ TESTS MOSTLY PASSED (${passRate}%)${colors.reset}\n`);
    return 1;
  } else {
    console.log(`${colors.red}✗ TESTS FAILED (${passRate}%)${colors.reset}\n`);
    return 1;
  }
}

// Run all tests
async function runAllTests() {
  console.log(`${colors.cyan}╔════════════════════════════════════════════════════════╗${colors.reset}`);
  console.log(`${colors.cyan}║      WorkVPN Desktop - Integration Test Suite         ║${colors.reset}`);
  console.log(`${colors.cyan}║              Platform 1: Electron App                  ║${colors.reset}`);
  console.log(`${colors.cyan}╚════════════════════════════════════════════════════════╝${colors.reset}\n`);

  try {
    checkCompiledFiles();
    testConfigParser();
    testConfigValidation();
    testConfigGeneration();
    testFileOperations();
    testRendererFiles();
    testAssets();
    testDocumentation();

    const exitCode = printResults();
    process.exit(exitCode);

  } catch (error) {
    console.error(`\n${colors.red}FATAL ERROR:${colors.reset}`, error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run tests
runAllTests();
