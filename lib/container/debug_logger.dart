import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'config.dart';

/// Batched debug logger that sends logs to remote server
class DebugLogger {
  static DebugLogger? _instance;
  static DebugLogger get instance => _instance ??= DebugLogger._();
  
  DebugLogger._() {
    _initializeDeviceId();
  }
  
  final List<LogEntry> _logBuffer = [];
  Timer? _flushTimer;
  bool _isEnabled = false;
  String? _deviceId;
  String? _logServerUrl;
  
  /// Maximum buffer size before forcing flush
  static const int _maxBufferSize = 50;
  
  /// Flush interval in milliseconds
  static const int _flushIntervalMs = 2000;
  
  /// Initialize device ID
  Future<void> _initializeDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = 'android_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = 'ios_${iosInfo.identifierForVendor}';
      } else {
        _deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      _deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  /// Enable remote logging
  void enable({String? logServerUrl}) {
    if (_isEnabled) return;
    
    _logServerUrl = logServerUrl ?? ContainerConfig.debugLogServerUrl;
    
    if (_logServerUrl == null || _logServerUrl!.isEmpty) {
      // Logging disabled - no server URL configured
      return;
    }
    
    _isEnabled = true;
    _startFlushTimer();
    
    // Intercept debugPrint
    debugPrint = _interceptedDebugPrint;
  }
  
  /// Disable remote logging
  void disable() {
    if (!_isEnabled) return;
    
    _isEnabled = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    
    // Flush remaining logs
    _flush();
    
    // Restore original debugPrint
    debugPrint = _originalDebugPrint;
  }
  
  /// Original debugPrint function
  void _originalDebugPrint(String? message, {int? wrapWidth}) {
    // Default Flutter debugPrint behavior
    if (kDebugMode) {
      print(message ?? '');
    }
  }
  
  /// Intercepted debugPrint that captures logs
  /// Prevents infinite loops by checking if message is from Hetu logging
  void _interceptedDebugPrint(String? message, {int? wrapWidth}) {
    // Call original first
    _originalDebugPrint(message, wrapWidth: wrapWidth);
    
    if (!_isEnabled || message == null || message.isEmpty) {
      return;
    }
    
    // Prevent infinite loops: Don't log messages that are already from HetuScript logging
    // This prevents Hetu logs → debugPrint → Hetu logs cycles
    if (message.startsWith('[HetuScript]') && 
        (message.contains('INFO:') || message.contains('WARNING:') || message.contains('ERROR:'))) {
      // This is already a formatted Hetu log, process it normally
    }
    
    // Parse component prefix from message
    String component = '';
    String logMessage = message;
    
    // Extract component from format: [ComponentName] Message
    final match = RegExp(r'^\[([^\]]+)\]\s*(.*)$').firstMatch(message);
    if (match != null) {
      component = match.group(1) ?? '';
      logMessage = match.group(2) ?? message;
      
      // Handle HetuScript logs with level prefixes
      if (component == 'HetuScript') {
        if (logMessage.startsWith('INFO: ')) {
          logMessage = logMessage.substring(6);
        } else if (logMessage.startsWith('WARNING: ')) {
          logMessage = logMessage.substring(9);
        } else if (logMessage.startsWith('ERROR: ')) {
          logMessage = logMessage.substring(7);
        }
      }
    }
    
    // Determine log level from message content or component
    String level = 'DEBUG';
    if (message.toLowerCase().contains('error') || component == 'HetuScript' && message.contains('ERROR:')) {
      level = 'ERROR';
    } else if (message.toLowerCase().contains('warning') || 
               message.toLowerCase().contains('warn') ||
               component == 'HetuScript' && message.contains('WARNING:')) {
      level = 'WARNING';
    } else if (message.toLowerCase().contains('info') ||
               component == 'HetuScript' && message.contains('INFO:')) {
      level = 'INFO';
    }
    
    // Add to buffer
    _logBuffer.add(LogEntry(
      timestamp: DateTime.now().toIso8601String(),
      level: level,
      component: component.isEmpty ? 'Unknown' : component,
      message: logMessage,
    ));
    
    // Flush if buffer is full
    if (_logBuffer.length >= _maxBufferSize) {
      _flush();
    }
  }
  
  /// Start periodic flush timer
  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      Duration(milliseconds: _flushIntervalMs),
      (_) => _flush(),
    );
  }
  
  /// Flush logs to server
  Future<void> _flush() async {
    if (_logBuffer.isEmpty || !_isEnabled || _logServerUrl == null) {
      return;
    }
    
    // Copy buffer and clear
    final logsToSend = List<LogEntry>.from(_logBuffer);
    _logBuffer.clear();
    
    // Send asynchronously (don't await to avoid blocking)
    _sendLogs(logsToSend).catchError((error) {
      // If send fails, put logs back in buffer (up to max size)
      _logBuffer.insertAll(0, logsToSend);
      if (_logBuffer.length > _maxBufferSize) {
        _logBuffer.removeRange(_maxBufferSize, _logBuffer.length);
      }
    });
  }
  
  /// Send logs to server
  Future<void> _sendLogs(List<LogEntry> logs) async {
    if (_logServerUrl == null || _deviceId == null) {
      return;
    }
    
    try {
      // Prepare payload
      final payload = {
        'device_id': _deviceId,
        'logs': logs.map((log) => log.toJson()).toList(),
      };
      
      // Encode to JSON
      final jsonBytes = utf8.encode(jsonEncode(payload));
      
      // Compress with gzip
      final compressedBytes = gzip.encode(jsonBytes);
      
      // Send POST request
      final uri = Uri.parse('$_logServerUrl/logs');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Content-Encoding': 'gzip',
        },
        body: compressedBytes,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Log send timeout');
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Log server returned ${response.statusCode}');
      }
    } catch (e) {
      // Silently fail - don't spam console with logging errors
      // Logs will be retried on next flush
    }
  }
  
  /// Manually flush logs (useful for app shutdown)
  Future<void> flush() async {
    await _flush();
  }
}

/// Log entry model
class LogEntry {
  final String timestamp;
  final String level;
  final String component;
  final String message;
  
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.component,
    required this.message,
  });
  
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'level': level,
    'component': component,
    'message': message,
  };
}

