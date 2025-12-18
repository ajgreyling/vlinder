# Vlinder Usage Guide

## Quick Start

### 1. Start Development Server

```bash
# Start Python server and ngrok tunnel
./scripts/start_dev_server.sh
```

This will:
- Start a Python HTTP server on port 8000 serving `.ht` files from `server/assets/`
- Start an ngrok tunnel exposing the server
- Display the public ngrok URL

### 2. Add Your .ht Files

Place your Hetu script files in `server/assets/`:
- `ui.ht` - UI definitions
- `schema.ht` - Entity schemas
- `workflows.ht` - Workflow definitions
- `rules.ht` - Business rules

### 3. Build Container App

```bash
# Build Android APK
./scripts/build_container.sh <ngrok_url> android

# Build iOS app
./scripts/build_container.sh <ngrok_url> ios
```

The build script will:
- Inject the ngrok URL into the app configuration
- Build the Flutter app for the target platform
- Output the built app

## Development Workflow

1. **Edit .ht files** in `server/assets/` or `sample_app/assets/`
2. **Start server** with `./scripts/start_dev_server.sh`
3. **Build app** with the ngrok URL
4. **Test on device** - app will fetch .ht files from server
5. **Update .ht files** - changes are immediately available (no rebuild needed)

## Sample App

The `sample_app/assets/` directory contains example .ht files demonstrating:
- Form with validation
- Multi-step workflow
- Business rules
- Schema definitions

Copy these to `server/assets/` to test:

```bash
cp sample_app/assets/*.ht server/assets/
```

## Container App Features

The container app (`lib/container/app_shell.dart`):
- Fetches .ht files from server on startup
- Caches assets locally for offline use
- Automatically falls back to cache if server unavailable
- Loads schemas, workflows, and rules
- Initializes Drift database from schemas
- Renders UI from ui.ht

## Configuration

Server URL is configured in `lib/container/config.dart`:
- Set via `VLINDER_SERVER_URL` environment variable at build time
- Or injected by build script from ngrok URL
- Falls back to `http://localhost:8000` for development

## Troubleshooting

### Server won't start
- Check Python 3 is installed: `python3 --version`
- Ensure port 8000 is available
- Check `server/assets/` directory exists

### Ngrok not working
- Install ngrok from https://ngrok.com/download
- Ensure ngrok is authenticated: `ngrok config add-authtoken <token>`
- Check ngrok status: http://localhost:4040

### App can't fetch assets
- Verify ngrok URL is correct
- Check server is running: `curl http://localhost:8000/ui.ht`
- Verify CORS headers (server includes CORS support)
- Check device has internet connection

### Build fails
- Ensure Flutter is installed and configured
- Check all dependencies: `flutter pub get`
- Verify ngrok URL is valid

