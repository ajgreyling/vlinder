#!/usr/bin/env python3
"""
Vlinder Debug Log Server
Receives batched debug logs from Flutter container app
Supports compression and efficient batching
"""

import http.server
import socketserver
import json
import gzip
import sys
from datetime import datetime
from pathlib import Path

# Default port for log server
LOG_PORT = 8001

# Log storage directory
LOG_DIR = Path(__file__).parent / 'logs'
LOG_DIR.mkdir(exist_ok=True)

class LogRequestHandler(http.server.BaseHTTPRequestHandler):
    """HTTP request handler for receiving debug logs"""
    
    def log_message(self, format, *args):
        """Suppress default HTTP server logs"""
        pass
    
    def do_POST(self):
        """Handle POST requests with batched logs"""
        # Route to /logs endpoint
        if self.path == '/logs' or self.path == '/':
            self._handle_logs()
        else:
            self.send_response(404)
            self.end_headers()
    
    def _handle_logs(self):
        """Process log POST request"""
        try:
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            content_encoding = self.headers.get('Content-Encoding', '')
            
            if content_length == 0:
                self.send_response(400)
                self.end_headers()
                return
            
            body = self.rfile.read(content_length)
            
            # Decompress if gzipped
            if content_encoding == 'gzip':
                body = gzip.decompress(body)
            
            # Parse JSON
            try:
                log_data = json.loads(body.decode('utf-8'))
            except json.JSONDecodeError as e:
                print(f"[LogServer] Invalid JSON: {e}", file=sys.stderr)
                self.send_response(400)
                self.end_headers()
                return
            
            # Process logs
            device_id = log_data.get('device_id', 'unknown')
            logs = log_data.get('logs', [])
            timestamp = datetime.now().isoformat()
            
            # Write to file (one file per device per day)
            log_file = LOG_DIR / f"{device_id}_{datetime.now().strftime('%Y%m%d')}.log"
            
            with open(log_file, 'a', encoding='utf-8') as f:
                for log_entry in logs:
                    log_line = json.dumps({
                        'timestamp': log_entry.get('timestamp', timestamp),
                        'level': log_entry.get('level', 'DEBUG'),
                        'component': log_entry.get('component', ''),
                        'message': log_entry.get('message', ''),
                        'device_id': device_id,
                    }, ensure_ascii=False)
                    f.write(log_line + '\n')
            
            # Also print to console for real-time viewing
            for log_entry in logs:
                component = log_entry.get('component', '')
                message = log_entry.get('message', '')
                level = log_entry.get('level', 'DEBUG')
                print(f"[{level}] [{component}] {message}")
            
            # Send success response
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'ok', 'received': len(logs)}).encode())
            
        except Exception as e:
            print(f"[LogServer] Error processing logs: {e}", file=sys.stderr)
            self.send_response(500)
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'error', 'message': str(e)}).encode())
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Content-Encoding')
        self.end_headers()
    
    def do_GET(self):
        """Handle GET requests - return server status"""
        if self.path == '/health' or self.path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                'status': 'ok',
                'service': 'vlinder-log-server',
                'port': LOG_PORT,
            }).encode())
        else:
            self.send_response(404)
            self.end_headers()

def main():
    """Start the log server"""
    # Ensure log directory exists
    LOG_DIR.mkdir(exist_ok=True)
    
    # Create server
    with socketserver.TCPServer(("", LOG_PORT), LogRequestHandler) as httpd:
        print(f"Vlinder Log Server")
        print(f"==================")
        print(f"Listening on: http://localhost:{LOG_PORT}")
        print(f"Log directory: {LOG_DIR}")
        print(f"\nPress Ctrl+C to stop the server")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\nLog server stopped.")

if __name__ == '__main__':
    main()
