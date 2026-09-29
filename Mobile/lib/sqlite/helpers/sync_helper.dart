import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

typedef OnlineSyncCallback = Future<void> Function();

class SyncHelper {
  static final SyncHelper instance = SyncHelper._internal();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  OnlineSyncCallback? _onOnlineCallback;
  bool _isOnline = true;

  SyncHelper._internal();

  factory SyncHelper() => instance;

  bool get isOnline => _isOnline;

  void init({OnlineSyncCallback? onOnline}) {
    _onOnlineCallback = onOnline;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasNet = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.ethernet);

      if (hasNet && !_isOnline) {
        debugPrint('[SyncHelper] Device reconnected to internet. Triggering sync...');
        _isOnline = true;
        _onOnlineCallback?.call();
      } else if (!hasNet) {
        debugPrint('[SyncHelper] Device is offline.');
        _isOnline = false;
      }
    });
  }

  Future<bool> checkCurrentConnection() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet);
    return _isOnline;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
