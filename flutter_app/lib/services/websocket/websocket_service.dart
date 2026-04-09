import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../domain/entities/asr_result.dart';
import '../../core/errors/exceptions.dart';

/// WebSocket service for communicating with the VibeVoice-ASR cloud server.
/// Implements exponential backoff reconnection per D-18.
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  
  /// Exponential backoff configuration (D-18)
  static const int maxRetries = 5;
  static const Duration baseDelay = Duration(seconds: 1);
  static const Duration maxDelay = Duration(seconds: 30);
  
  int _retryCount = 0;
  Duration _currentDelay = baseDelay;
  bool _disposed = false;
  String? _lastUrl;
  Timer? _reconnectTimer;
  
  ConnectionState _state = ConnectionState.disconnected;
  final StreamController<ConnectionState> _stateController =
      StreamController<ConnectionState>.broadcast();
  
  Stream<ConnectionState> get connectionStateAsStream => _stateController.stream;
  ConnectionState get connectionState => _state;
  
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  
  Future<void> connect(String url) async {
    if (_disposed) return;
    
    _lastUrl = url;
    _retryCount = 0;
    _currentDelay = baseDelay;
    _updateState(ConnectionState.connecting);
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
      
      _updateState(ConnectionState.connected);
    } on WebSocketChannelException catch (e) {
      await _handleDisconnect(e);
    } catch (e) {
      debugPrint('WebSocket unexpected error: $e');
      await _handleDisconnect(e);
    }
  }
  
  void _updateState(ConnectionState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
  
  void _onMessage(dynamic message) {
    if (_disposed) return;
    
    try {
      if (message is String) {
        final json = jsonDecode(message) as Map<String, dynamic>;
        _messageController.add(json);
      } else if (message is List<int>) {
        _messageController.add({'type': 'binary', 'data': message});
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }
  
  void _onError(Object error) {
    if (_disposed) return;
    debugPrint('WebSocket error: $error');
    _handleDisconnect(error);
  }
  
  void _onDone() {
    if (_disposed) return;
    debugPrint('WebSocket connection closed');
    _handleDisconnect('Connection closed');
  }
  
  Future<void> _handleDisconnect(Object error) async {
    if (_disposed || _state == ConnectionState.disconnected) {
      return;
    }
    
    if (_retryCount >= maxRetries) {
      debugPrint('Max retries reached ($maxRetries). Giving up.');
      _updateState(ConnectionState.failed);
      return;
    }
    
    _updateState(ConnectionState.reconnecting);
    
    debugPrint(
      'Reconnecting in ${_currentDelay.inSeconds}s '
      '(attempt ${_retryCount + 1}/$maxRetries)...',
    );
    
    await Future.delayed(_currentDelay);
    
    // Double the delay, capped at maxDelay
    _currentDelay = Duration(
      milliseconds: (_currentDelay.inMilliseconds * 2).clamp(
        baseDelay.inMilliseconds,
        maxDelay.inMilliseconds,
      ),
    );
    
    _retryCount++;
    
    if (_lastUrl != null && !_disposed) {
      await connect(_lastUrl!);
    }
  }
  
  void sendStart({required String language}) {
    if (_channel == null || _disposed) return;
    
    final message = jsonEncode({
      'type': 'start',
      'language': language,
    });
    
    _channel!.sink.add(message);
  }
  
  void sendAudioChunk(Uint8List chunk) {
    if (_channel == null || _disposed) return;
    _channel!.sink.add(chunk);
  }
  
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _retryCount = maxRetries;
    _updateState(ConnectionState.disconnected);
    await _channel?.sink.close();
    _channel = null;
  }
  
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _stateController.close();
    _channel?.sink.close();
    _messageController.close();
  }
}
