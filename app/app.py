from http.server import BaseHTTPRequestHandler, HTTPServer
import os


class Handler(BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"healthy")
            return

        if self.path == "/":
            environment = os.getenv("ENVIRONMENT", "staging")
            message = f"8Byte DevOps Assignment - {environment}"
            self.send_response(200)
            self.end_headers()
            self.wfile.write(message.encode())
            return

        self.send_response(404)
        self.end_headers()


def main():
    server = HTTPServer(("0.0.0.0", 8080), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
