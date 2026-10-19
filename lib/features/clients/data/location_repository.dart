import 'dart:convert';
import 'dart:typed_data';

import 'package:mountain_fairytale/core/network/api_client.dart';

class DeliveryAddress {
  final String district, locality, street, house, deliveryDetails, source;
  final double latitude, longitude;
  const DeliveryAddress({
    required this.district,
    required this.locality,
    required this.street,
    required this.house,
    required this.latitude,
    required this.longitude,
    this.deliveryDetails = '',
    this.source = 'geoapify',
  });
  String get formatted => [
    'Ставропольский край',
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
    'deliveryDetails': deliveryDetails,
  };
  factory DeliveryAddress.fromJson(Map<String, dynamic> j) => DeliveryAddress(
    district: j['district'] as String,
    locality: j['locality'] as String,
    street: j['street'] as String,
    house: j['house'] as String,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    deliveryDetails: j['deliveryDetails'] as String? ?? '',
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
  LocationRepository(this._client);
  final Map<String, Future<Uint8List>> _tiles = {};
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
    if (_tiles.length > 160) _tiles.clear();
    return _tiles.putIfAbsent(path, () async {
      try {
        final r = await _client.get(path);
        return base64Decode((r['data'] as Map)['png'] as String);
      } catch (_) {
        _tiles.remove(path);
        rethrow;
      }
    });
  }
}
