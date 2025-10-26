#!/usr/bin/env python3
"""
VPN Manager Web UI Server
Simple HTTP server to serve the management interface
"""

import http.server
import socketserver
import webbrowser
import os
import sys
from pathlib import Path

# Configuration
PORT = 3000
HOST = '0.0.0.0'

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers to allow cross-origin requests
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        super().end_headers()

    def do_OPTIONS(self):
        # Handle preflight requests
        self.send_response(200)
        self.end_headers()

def main():
    # Change to the web-ui directory
    web_ui_dir = Path(__file__).parent
    os.chdir(web_ui_dir)
    
    print("🔐 VPN Manager Web UI Server")
    print("=" * 40)
    print(f"Starting server on http://{HOST}:{PORT}")
    print(f"Serving files from: {web_ui_dir}")
    print()
    print("Available endpoints:")
    print(f"  Web UI: http://localhost:{PORT}")
    print(f"  Web UI: http://{HOST}:{PORT}")
    print()
    print("Press Ctrl+C to stop the server")
    print("=" * 40)
    
    try:
        with socketserver.TCPServer((HOST, PORT), CustomHTTPRequestHandler) as httpd:
            print(f"✅ Server started successfully!")
            print(f"🌐 Open your browser and go to: http://localhost:{PORT}")
            print()
            
            # Try to open browser automatically
            try:
                webbrowser.open(f'http://localhost:{PORT}')
                print("🚀 Browser opened automatically")
            except:
                print("💡 Please open your browser manually")
            
            print()
            print("📋 Management Server Configuration:")
            print("  Default URL: http://192.168.10.248:8080")
            print("  API Key: (enter your API key in the web interface)")
            print()
            print("🛠️  Available Features:")
            print("  • Health Check - Test management server connectivity")
            print("  • User Management - Create, list, delete users")
            print("  • End-Node Management - Register and monitor end-nodes")
            print("  • User Sync - Synchronize users across end-nodes")
            print("  • System Logs - View recent system activity")
            print()
            
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
        sys.exit(0)
    except OSError as e:
        if e.errno == 98:  # Address already in use
            print(f"❌ Error: Port {PORT} is already in use")
            print(f"💡 Try a different port or stop the service using port {PORT}")
            sys.exit(1)
        else:
            print(f"❌ Error: {e}")
            sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
