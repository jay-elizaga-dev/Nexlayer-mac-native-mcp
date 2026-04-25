# Development Setup

## First-time setup

Copy your API key to the stable config location (works with Xcode and run.sh):

```bash
mkdir -p ~/.config/mac-native-mcp
echo "NEXLAYER_API_KEY=your-key-here" > ~/.config/mac-native-mcp/dev.env
```

Or copy from the project:

```bash
cp dev.env ~/.config/mac-native-mcp/dev.env
```

## Running the app

**Xcode (recommended for development)**

```bash
open Package.swift
```

Hit ▶. The app reads the API key from `~/.config/mac-native-mcp/dev.env`, pre-populates the login field, click Connect.

**run.sh (terminal shortcut)**

```bash
./run.sh
```

Builds and launches `MacNativeMCP.app` from the project root. Reads `dev.env` from the project root.

## API key locations

The app checks these in order (DEBUG builds only):

1. `{project root}/dev.env` — used by run.sh
2. `~/.config/mac-native-mcp/dev.env` — used by Xcode

Both use the same format:

```
NEXLAYER_API_KEY=nx_live_...
```

`dev.env` is gitignored. Never commit it.

## Get an API key

https://app.nexlayer.com/settings/api-keys
