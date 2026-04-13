import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/entities/asr_result.dart';
import 'providers.dart';

/// Provider for network connectivity status.
/// Listens to system connectivity changes and exposes them.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Provider for current network availability.
/// Returns true if at least one network interface is available.
final isNetworkAvailableProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.maybeWhen(
    data: (results) => !results.contains(ConnectivityResult.none),
    orElse: () => false,
  );
});

/// Provider for the WebSocket connection state as a stream.
/// Listens to the WebSocketService connection state changes.
final connectionStateStreamProvider = StreamProvider<WsConnectionState>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return wsService.connectionStateAsStream;
});

/// Provider for the current WebSocket connection state (synchronous access).
/// Returns the latest state synchronously from the stream.
final currentWsConnectionStateProvider = Provider<WsConnectionState>((ref) {
  final stateAsync = ref.watch(connectionStateStreamProvider);
  return stateAsync.maybeWhen(
    data: (state) => state,
    orElse: () => WsConnectionState.disconnected,
  );
});

/// Provider for whether the app can attempt recording.
/// Returns true when connected (or disconnected — user can retry).
final canRecordProvider = Provider<bool>((ref) {
  final state = ref.watch(currentWsConnectionStateProvider);
  return state.canRecord;
});
