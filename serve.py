import http.server
import socketserver
import os

PORT = 5000
DIRECTORY = "build/web"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        # Prevent service-worker and index from being cached so reloads pick up fresh builds
        path = self.path.split('?')[0]
        if path in ('/', '/index.html', '/flutter_service_worker.js', '/flutter.js'):
            self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
            self.send_header('Pragma', 'no-cache')
        super().end_headers()

    def log_message(self, format, *args):
        pass

os.chdir(os.path.dirname(os.path.abspath(__file__)))

with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
    print(f"Serving Flutter web app at http://0.0.0.0:{PORT}")
    httpd.serve_forever()
