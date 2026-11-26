import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class ConnectivityService {
  Future<bool> get isConnected;
  Stream<bool> get onStatusChanged;
}

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  Future<bool> get isConnected async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _hasConnection(results);
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    } on Object {
      return true;
    }
  }

  @override
  Stream<bool> get onStatusChanged {
    try {
      return _connectivity.onConnectivityChanged.map(_hasConnection);
    } on Object {
      return Stream<bool>.value(true);
    }
  }
}

class DummyConnectivityService implements ConnectivityService {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onStatusChanged => Stream<bool>.value(true);
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityPlusService();
});
