# Debug Logging System

Vlinder includes a modern, data-efficient remote debug logging system that captures logs from the Flutter container app and sends them to a Python logging server.

## Architecture

- **Dart Logging Client** (`lib/container/debug_logger.dart`): Intercepts `debugPrint()` calls, batches logs, compresses them with gzip, and sends to remote server
- **Python Log Server** (`server/log_server.py`): Receives batched logs, decompresses, stores to files, and prints to console
- **Batching**: Logs are batched (max 50 logs or 2 seconds) to reduce network calls
- **Compression**: Logs are gzip-compressed before sending to minimize data usage

## Features

- ✅ Automatic log interception (no code changes needed)
- ✅ Efficient batching (reduces network calls)
- ✅ Gzip compression (minimizes data usage)
- ✅ Component-based filtering (`[ComponentName]` prefix parsing)
- ✅ Log level detection (DEBUG, INFO, WARNING, ERROR)
- ✅ Persistent storage (one file per device per day)
- ✅ Real-time console output
- ✅ Graceful failure handling (logs retried on next flush)

## Setup

### 1. Start the Log Server

The log server starts automatically with the development server:

```bash
./scripts/start_dev_server.sh
```

Or start it manually:

```bash
cd server
python3 log_server.py
```

The log server runs on port **8001** by default.

### 2. Expose via Ngrok (for remote devices)

For remote devices (physical phones, etc.), expose the log server via ngrok:

#### Option A: Separate Ngrok Tunnel (Recommended)

```bash
# In a separate terminal
ngrok http 8001
```

Copy the ngrok URL (e.g., `https://abc123.ngrok.io`) and use it when building:

```bash
flutter run --dart-define=VLINDER_LOG_SERVER_URL="https://abc123.ngrok.io"
```

#### Option B: Ngrok Config File (Multiple Tunnels)

Create `~/.ngrok2/ngrok.yml`:

```yaml
tunnels:
  assets:
    addr: 8000
    proto: http
  logs:
    addr: 8001
    proto: http
```

Then start ngrok with config:

```bash
ngrok start --all
```

### 3. Build Container App with Log Server URL

```bash
# Local development (localhost)
flutter run --dart-define=VLINDER_LOG_SERVER_URL="http://localhost:8001"

# Remote (via ngrok)
flutter run --dart-define=VLINDER_LOG_SERVER_URL="https://your-ngrok-url.ngrok.io"
```

Or set it in the build script:

```bash
./scripts/build_container.sh <ngrok_asset_url> android --log-server-url="https://your-ngrok-url.ngrok.io"
```

## Usage

### Automatic Logging

Once enabled, all `debugPrint()` calls are automatically captured and sent to the log server. No code changes needed!

```dart
debugPrint('[ContainerAppShell] Starting app initialization');
debugPrint('[VlinderDatabase] Creating table from schema: users');
debugPrint('[UIParser] Parsing UI script');
```

### Manual Control

```dart
import 'package:vlinder/container/debug_logger.dart';

// Enable logging (done automatically in app_shell.dart)
DebugLogger.instance.enable(logServerUrl: 'http://localhost:8001');

// Disable logging
DebugLogger.instance.disable();

// Manually flush logs
await DebugLogger.instance.flush();
```

## Log Format

Logs are stored in JSON format, one per line:

```json
{"timestamp": "2024-01-15T10:30:45.123Z", "level": "DEBUG", "component": "ContainerAppShell", "message": "Starting app initialization", "device_id": "android_abc123"}
```

## Log Files

Logs are stored in `server/logs/` directory:
- Format: `{device_id}_{YYYYMMDD}.log`
- Example: `android_abc123_20240115.log`

## Configuration

### Environment Variables

- `VLINDER_LOG_SERVER_URL`: Log server URL (set at build time)

### Dart Constants

In `lib/container/debug_logger.dart`:
- `_maxBufferSize`: Maximum logs before flush (default: 50)
- `_flushIntervalMs`: Flush interval in milliseconds (default: 2000)

## Troubleshooting

### Logs not appearing

1. Check log server is running: `curl http://localhost:8001/health`
2. Check device can reach server (network/firewall)
3. Check logs in `server/logs/` directory
4. Enable verbose logging in Flutter: `flutter run --verbose`

### High data usage

- Reduce `_flushIntervalMs` (less frequent flushes)
- Increase `_maxBufferSize` (more logs per batch)
- Disable logging in production builds

### Ngrok issues

- Free ngrok plan supports one tunnel - use separate ngrok instances or config file
- Paid ngrok plan supports multiple tunnels natively
- Consider using local network IP for local testing

## Performance

- **Network overhead**: Minimal (gzip compression, batching)
- **App performance**: Negligible (async sending, non-blocking)
- **Battery impact**: Low (batched sends, efficient compression)

## Security

⚠️ **Note**: Logs may contain sensitive information. Ensure:
- Use HTTPS for remote log servers (via ngrok HTTPS)
- Don't expose log server publicly in production
- Review logs before sharing
- Consider log filtering/redaction for sensitive data


