#!/usr/bin/env python3
"""
Simple HTTP server for serving Vlinder .ht files
Supports CORS for mobile app access
"""

import http.server
import socketserver
import os
import sys
from pathlib import Path

# Default port (internal - accessed via reverse proxy)
PORT = 8002

# Get assets directory
ASSETS_DIR = Path(__file__).parent / 'assets'

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP request handler with CORS support"""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ASSETS_DIR), **kwargs)
    
    def end_headers(self):
        """Add CORS headers to all responses"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()
    
    def do_OPTIONS(self):
        """Handle OPTIONS requests for CORS preflight"""
        self.send_response(200)
        self.end_headers()
    
    def log_message(self, format, *args):
        """Custom log format"""
        print(f"[{self.log_date_time_string()}] {format % args}")

def main():
    """Start the HTTP server"""
    # Ensure assets directory exists
    if not ASSETS_DIR.exists():
        print(f"Error: Assets directory not found: {ASSETS_DIR}")
        print(f"Creating directory...")
        ASSETS_DIR.mkdir(parents=True, exist_ok=True)
        print(f"Please add .ht files to {ASSETS_DIR}")
        sys.exit(1)
    
    # Check if assets directory has files
    ht_files = list(ASSETS_DIR.glob('*.ht'))
    if not ht_files:
        print(f"Warning: No .ht files found in {ASSETS_DIR}")
        print(f"Expected files: ui.ht, schema.ht, workflows.ht, rules.ht, actions.ht")
    
    # Create server
    with socketserver.TCPServer(("", PORT), CORSRequestHandler) as httpd:
        print(f"Vlinder Asset Server")
        print(f"===================")
        print(f"Serving assets from: {ASSETS_DIR}")
        print(f"Server running on: http://localhost:{PORT}")
        print(f"Available files:")
        for ht_file in ht_files:
            print(f"  - {ht_file.name}")
        print(f"\nPress Ctrl+C to stop the server")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\nServer stopped.")

if __name__ == '__main__':
    main()

