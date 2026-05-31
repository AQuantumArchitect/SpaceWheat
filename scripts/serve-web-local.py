#!/usr/bin/env python3
"""Serve a SpaceWheat web export with first-load COOP/COEP headers."""

from __future__ import annotations

import argparse
import functools
import http.server
import pathlib
import socketserver


class SpaceWheatWebHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        super().end_headers()


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Serve a SpaceWheat web export with isolation headers."
    )
    parser.add_argument(
        "directory",
        nargs="?",
        default="releases/web-local",
        help="Directory to serve (default: releases/web-local)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8000,
        help="Port to bind (default: 8000)",
    )
    args = parser.parse_args()

    directory = pathlib.Path(args.directory).resolve()
    if not directory.is_dir():
        raise SystemExit(f"Serve directory does not exist: {directory}")

    handler = functools.partial(SpaceWheatWebHandler, directory=str(directory))
    with ReusableTCPServer(("127.0.0.1", args.port), handler) as httpd:
        print(f"Serving {directory} on http://127.0.0.1:{args.port}")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
