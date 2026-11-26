import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class GeoLocationData {
  const GeoLocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.label,
    required this.shortLink,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String label;
  final String shortLink;
}

abstract interface class LocationService {
  Future<GeoLocationData?> currentOrLastKnown({
    Duration timeout = const Duration(seconds: 3),
  });
}

class GeolocatorLocationService implements LocationService {
  GeoLocationData _fromPosition(Position pos, {bool isLastKnown = false}) {
    final lat = pos.latitude.toStringAsFixed(5);
    final lng = pos.longitude.toStringAsFixed(5);
    final acc = pos.accuracy.isFinite ? pos.accuracy.round() : 10;
    return GeoLocationData(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracyMeters: pos.accuracy,
      label: isLastKnown
          ? 'Lokasi terakhir ($lat, $lng)'
          : 'GPS presisi (±${acc}m)',
      shortLink: 'https://maps.google.com/?q=$lat,$lng',
    );
  }

  Future<GeoLocationData?> _tryLastKnown() async {
    if (kIsWeb) return null;
    try {
      final last = await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 1));
      return last != null ? _fromPosition(last, isLastKnown: true) : null;
    } on Object {
      return null;
    }
  }

  Future<GeoLocationData?> _fetchInternal(Duration timeout) async {
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }

    // On Web, geolocator_web's requestPermission() calls getCurrentPosition without
    // a timeout, which can hang forever on desktop browsers. Call getCurrentPosition
    // directly with a strict timeLimit + outer timeout instead.
    if (kIsWeb) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: timeout,
          ),
        ).timeout(timeout);
        return _fromPosition(pos);
      } on Object {
        return null;
      }
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _tryLastKnown();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _tryLastKnown();
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return _fromPosition(pos);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return _tryLastKnown();
    } on Object {
      return _tryLastKnown();
    }
  }

  @override
  Future<GeoLocationData?> currentOrLastKnown({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      return await _fetchInternal(timeout).timeout(
        timeout,
        onTimeout: () => null,
      );
    } on Object {
      return null;
    }
  }
}

class DummyLocationService implements LocationService {
  @override
  Future<GeoLocationData?> currentOrLastKnown({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const GeoLocationData(
      latitude: -6.2088,
      longitude: 106.8456,
      accuracyMeters: 4.5,
      label: 'Lokasi Uji · GPS',
      shortLink: 'https://maps.google.com/?q=-6.2088,106.8456',
    );
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService();
});
