import 'dart:convert';
import 'dart:typed_data';

import 'package:mountain_fairytale/core/network/api_client.dart';

class DeliveryAddress {
  final String district, locality, street, house, source;
  final double latitude, longitude;
  const DeliveryAddress({
    required this.district,
    required this.locality,
    required this.street,
    required this.house,
    required this.latitude,
    required this.longitude,
    this.source = 'geoapify',
  });
  String get formatted => [
    district,
    locality,
    street,
    house,
  ].where((part) => part.isNotEmpty).join(', ');
  Map<String, dynamic> toJson() => {
    'district': district,
    'locality': locality,
    'street': street,
    'house': house,
    'latitude': latitude,
    'longitude': longitude,
    'confirmed': true,
    'source': source,
  };
  factory DeliveryAddress.fromJson(Map<String, dynamic> j) => DeliveryAddress(
    district: j['district'] as String,
    locality: j['locality'] as String,
    street: j['street'] as String,
    house: j['house'] as String,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    source: j['source'] as String? ?? 'geoapify',
  );
}

class LocationCandidate {
  final String formatted;
  final double latitude, longitude, confidence;
  final bool exactHouse;
  LocationCandidate(Map<String, dynamic> j)
    : formatted = j['formatted'] as String,
      latitude = (j['latitude'] as num).toDouble(),
      longitude = (j['longitude'] as num).toDouble(),
      confidence = (j['confidence'] as num).toDouble(),
      exactHouse = j['exactHouse'] as bool;
}

class LocationRepository {
  final ApiClient _client;
  final DateTime Function() _now;
  LocationRepository(this._client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final _tiles = <String, ({Uint8List png, DateTime loadedAt})>{};
  final Map<String, Future<Uint8List>> _tileRequests = {};
  int _tileBytes = 0;
  static const _maxTileBytes = 16 * 1024 * 1024;
  static const _tileLifetime = Duration(minutes: 5);
  Future<List<LocationCandidate>> search(Map<String, String> address) async {
    final r = await _client.post('/protected/clients/geocode', body: address);
    return ((r['data'] as Map)['candidates'] as List)
        .map((e) => LocationCandidate(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> optimize(List<String> ids) async {
    final r = await _client.post(
      '/protected/delivery-route-sheets/optimize-order',
      body: {'orderedClientIds': ids},
    );
    return Map<String, dynamic>.from(r['data'] as Map);
  }

  Future<Uint8List> tile(int z, int x, int y) {
    final path = '/protected/locations/tiles/$z/$x/$y';
    final cached = _tiles.remove(path);
    if (cached != null) {
      if (_now().difference(cached.loadedAt) < _tileLifetime) {
        _tiles[path] = cached;
        return Future.value(cached.png);
      }
      _tileBytes -= cached.png.length;
    }
    return _tileRequests.putIfAbsent(path, () async {
      try {
        final r = await _client.get(path);
        final png = base64Decode((r['data'] as Map)['png'] as String);
        if (png.length <= _maxTileBytes) {
          _tiles[path] = (png: png, loadedAt: _now());
          _tileBytes += png.length;
          while (_tileBytes > _maxTileBytes || _tiles.length > 256) {
            _tileBytes -= _tiles.remove(_tiles.keys.first)!.png.length;
          }
        }
        return png;
      } finally {
        _tileRequests.remove(path);
      }
    });
  }
}
