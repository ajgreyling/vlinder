#!/usr/bin/env python3
"""
Reverse proxy router for Vlinder services
Routes requests to asset server and log server based on path
"""

import http.server
import socketserver
import urllib.request
import urllib.parse
import sys
from http.client import HTTPResponse

# Port for reverse proxy (public-facing)
PROXY_PORT = 8000

# Backend service URLs
ASSET_SERVER_URL = 'http://localhost:8002'
LOG_SERVER_URL = 'http://localhost:8001'

class ReverseProxyHandler(http.server.BaseHTTPRequestHandler):
    """HTTP request handler that proxies requests to backend services"""
    
    def log_message(self, format, *args):
        """Custom log format"""
        print(f"[ReverseProxy] {format % args}")
    
    def _proxy_request(self, target_url, method='GET', body=None, headers=None):
        """Proxy a request to a backend service"""
        try:
            # Parse target URL
            parsed_url = urllib.parse.urlparse(target_url)
            
            # Prepare request
            req = urllib.request.Request(target_url, data=body, method=method)
            
            # Copy headers from original request (excluding host and connection)
            if headers:
                for header, value in headers.items():
                    if header.lower() not in ['host', 'connection', 'content-length']:
                        req.add_header(header, value)
            
            # Add content-length if body exists
            if body:
                req.add_header('Content-Length', str(len(body)))
            
            # Make request to backend
            with urllib.request.urlopen(req, timeout=10) as response:
                # Read response
                response_data = response.read()
                
                # Send response back to client
                self.send_response(response.status)
                
                # Copy response headers (excluding connection)
                for header, value in response.headers.items():
                    if header.lower() != 'connection':
                        self.send_header(header, value)
                
                # Add CORS headers
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers', 'Content-Type, Content-Encoding')
                
                self.end_headers()
                self.wfile.write(response_data)
                
        except urllib.error.HTTPError as e:
            # Handle HTTP errors
            self.send_response(e.code)
            self.send_header('Content-Type', 'text/plain')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(f"Proxy error: {e.reason}".encode())
        except Exception as e:
            # Handle other errors
            print(f"[ReverseProxy] Error proxying request: {e}", file=sys.stderr)
            self.send_response(500)
            self.send_header('Content-Type', 'text/plain')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(f"Proxy error: {str(e)}".encode())
    
    def do_GET(self):
        """Handle GET requests"""
        # Route /logs/health and /health to log server
        if self.path == '/health' or self.path.startswith('/health'):
            target_url = f"{LOG_SERVER_URL}{self.path}"
            self._proxy_request(target_url, method='GET', headers=dict(self.headers))
        else:
            # Route everything else to asset server
            target_url = f"{ASSET_SERVER_URL}{self.path}"
            self._proxy_request(target_url, method='GET', headers=dict(self.headers))
    
    def do_POST(self):
        """Handle POST requests"""
        # Route /logs to log server
        if self.path == '/logs' or self.path.startswith('/logs'):
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None
            
            target_url = f"{LOG_SERVER_URL}{self.path}"
            self._proxy_request(target_url, method='POST', body=body, headers=dict(self.headers))
        else:
            # Route everything else to asset server
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None
            
            target_url = f"{ASSET_SERVER_URL}{self.path}"
            self._proxy_request(target_url, method='POST', body=body, headers=dict(self.headers))
    
    def do_OPTIONS(self):
        """Handle OPTIONS requests for CORS preflight"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Content-Encoding')
        self.end_headers()
    
    def do_PUT(self):
        """Handle PUT requests (proxy to asset server)"""
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else None
        
        target_url = f"{ASSET_SERVER_URL}{self.path}"
        self._proxy_request(target_url, method='PUT', body=body, headers=dict(self.headers))
    
    def do_DELETE(self):
        """Handle DELETE requests (proxy to asset server)"""
        target_url = f"{ASSET_SERVER_URL}{self.path}"
        self._proxy_request(target_url, method='DELETE', headers=dict(self.headers))

def main():
    """Start the reverse proxy server"""
    # Create server
    with socketserver.TCPServer(("", PROXY_PORT), ReverseProxyHandler) as httpd:
        print(f"Vlinder Reverse Proxy Router")
        print(f"============================")
        print(f"Listening on: http://localhost:{PROXY_PORT}")
        print(f"Asset Server: {ASSET_SERVER_URL}")
        print(f"Log Server: {LOG_SERVER_URL}")
        print(f"\nRouting:")
        print(f"  /logs, /health → Log Server ({LOG_SERVER_URL})")
        print(f"  /* → Asset Server ({ASSET_SERVER_URL})")
        print(f"\nPress Ctrl+C to stop the server")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\nReverse proxy stopped.")

if __name__ == '__main__':
    main()





