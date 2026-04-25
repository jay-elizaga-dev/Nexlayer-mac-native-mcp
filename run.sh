#!/bin/bash
set -e
cd "$(dirname "$0")"

swift build
cp .build/arm64-apple-macosx/debug/MacNativeMCP MacNativeMCP.app/Contents/MacOS/MacNativeMCP
pkill -f "MacNativeMCP.app" 2>/dev/null || true
sleep 0.3
open MacNativeMCP.app
