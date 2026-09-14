#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in {"/", "/healthz"}:
            self.send_response(404)
            self.end_headers()
            return

        payload = {
            "status": "ok",
            "service": "batch-processor",
            "replicas": int(os.getenv("REPLICAS", "1")),
        }
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return


def main():
    port = int(os.getenv("PORT", "80"))
    server = HTTPServer(("0.0.0.0", port), Handler)
    print(f"Batch processor listening on {port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
