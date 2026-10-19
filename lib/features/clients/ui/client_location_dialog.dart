import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/clients/data/location_repository.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/geo_attribution.dart';

Future<({double latitude, double longitude, bool manual})?>
showClientLocationDialog(
  BuildContext context, {
  required LocationRepository repository,
  required String address,
  required List<LocationCandidate> candidates,
  DeliveryAddress? existing,
}) => showDialog<({double latitude, double longitude, bool manual})>(
  context: context,
  builder: (_) => _LocationDialog(
    repository: repository,
    address: address,
    candidates: candidates,
    existing: existing,
  ),
);

class _LocationDialog extends StatefulWidget {
  final LocationRepository repository;
  final String address;
  final List<LocationCandidate> candidates;
  final DeliveryAddress? existing;
  const _LocationDialog({
    required this.repository,
    required this.address,
    required this.candidates,
    this.existing,
  });
  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  late double _lat, _lon, _centerLat, _centerLon;
  int _zoom = 17;
  bool _selected = false, _manual = false;
  String? _coordinateError;
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  Offset _drag = Offset.zero;
  @override
  void initState() {
    super.initState();
    final c = widget.candidates.firstOrNull;
    _lat = widget.existing?.latitude ?? c?.latitude ?? 45.1325;
    _lon = widget.existing?.longitude ?? c?.longitude ?? 42.0263;
    _centerLat = _lat;
    _centerLon = _lon;
    _selected = widget.existing != null || (c?.exactHouse ?? false);
    _manual = widget.existing?.source == 'manual';
    if (!_selected) _zoom = 12;
    _syncCoordinates();
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  double get _world => 256.0 * math.pow(2, _zoom);
  Offset _project(double lat, double lon) {
    final r = lat * math.pi / 180;
    return Offset(
      (lon + 180) / 360 * _world,
      (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * _world,
    );
  }

  ({double lat, double lon}) _unproject(Offset p) {
    final n = math.pi * (1 - 2 * p.dy / _world);
    return (
      lat: math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi,
      lon: p.dx / _world * 360 - 180,
    );
  }

  bool _inBounds(double lat, double lon) =>
      lat >= 43.4 && lat <= 46.6 && lon >= 40.8 && lon <= 45.9;
  void _syncCoordinates() {
    _latitude.text = _lat.toStringAsFixed(7);
    _longitude.text = _lon.toStringAsFixed(7);
  }

  void _select(double lat, double lon) {
    setState(() {
      if (!_inBounds(lat, lon)) {
        _coordinateError = 'Укажите место в Ставропольском крае';
        return;
      }
      _lat = lat;
      _lon = lon;
      _selected = true;
      _manual = true;
      _coordinateError = null;
      _syncCoordinates();
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Местоположение клиента'),
    content: SizedBox(
      width: 760,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.address),
            const SizedBox(height: 8),
            if (widget.existing != null)
              const Text(
                'Сохранённое местоположение. При необходимости поправьте метку.',
              )
            else if (widget.candidates.isNotEmpty) ...[
              Text('Найдено: ${widget.candidates.first.formatted}'),
              if (!widget.candidates.first.exactHouse ||
                  widget.candidates.first.confidence < 1)
                const Text(
                  'Проверьте дом и место подъезда. При необходимости выберите место на карте.',
                ),
            ] else
              const Text(
                'Дом не найден. Уточните адрес или выберите место на карте.',
              ),
            const SizedBox(height: 8),
            const Text(
              'Перетащите карту для перемещения. Нажмите на место или перетащите метку к нужному въезду.',
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 360,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final center = _project(_centerLat, _centerLon);
                  final size = Size(constraints.maxWidth, 360);
                  final origin =
                      center - Offset(size.width / 2, size.height / 2) - _drag;
                  final tx = (origin.dx / 256).floor(),
                      ty = (origin.dy / 256).floor();
                  final marker = _project(_lat, _lon) - origin;
                  return ClipRect(
                    child: GestureDetector(
                      onTapUp: (e) {
                        final p = _unproject(origin + e.localPosition);
                        _select(p.lat, p.lon);
                      },
                      onPanUpdate: (e) => setState(() => _drag += e.delta),
                      onPanEnd: (_) => setState(() {
                        final p = _unproject(center - _drag);
                        _centerLat = p.lat.clamp(43.4, 46.6);
                        _centerLon = p.lon.clamp(40.8, 45.9);
                        _drag = Offset.zero;
                      }),
                      child: ColoredBox(
                        color: Colors.grey.shade200,
                        child: Stack(
                          children: [
                            for (
                              var x = tx;
                              x <= ((origin.dx + size.width) / 256).floor();
                              x++
                            )
                              for (
                                var y = ty;
                                y <= ((origin.dy + size.height) / 256).floor();
                                y++
                              )
                                Positioned(
                                  left: x * 256 - origin.dx,
                                  top: y * 256 - origin.dy,
                                  width: 256,
                                  height: 256,
                                  child: FutureBuilder<Uint8List>(
                                    future: widget.repository.tile(_zoom, x, y),
                                    builder: (context, s) => s.hasData
                                        ? Image.memory(
                                            s.data!,
                                            fit: BoxFit.fill,
                                            gaplessPlayback: true,
                                          )
                                        : Center(
                                            child: Text(
                                              s.hasError
                                                  ? 'Карта недоступна'
                                                  : 'Загрузка…',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                            if (_selected)
                              Positioned(
                                left: marker.dx - 18,
                                top: marker.dy - 36,
                                child: GestureDetector(
                                  onPanUpdate: (event) {
                                    final moved = _unproject(
                                      _project(_lat, _lon) + event.delta,
                                    );
                                    _select(moved.lat, moved.lon);
                                  },
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 36,
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Column(
                                children: [
                                  AppIconButton(
                                    onPressed: _zoom < 19
                                        ? () => setState(() => _zoom++)
                                        : null,
                                    icon: Icons.add,
                                    tooltip: 'Приблизить',
                                  ),
                                  AppIconButton(
                                    icon: Icons.refresh,
                                    tooltip: 'Повторить загрузку карты',
                                    onPressed: () => setState(() {}),
                                  ),
                                  AppIconButton(
                                    onPressed: _zoom > 8
                                        ? () => setState(() => _zoom--)
                                        : null,
                                    icon: Icons.remove,
                                    tooltip: 'Отдалить',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const GeoAttribution(),
            ExpansionTile(
              title: const Text('Ввести координаты'),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitude,
                        onChanged: (_) => setState(() {
                          _selected = false;
                          _coordinateError = null;
                        }),
                        decoration: InputDecoration(
                          labelText: 'Широта',
                          border: const OutlineInputBorder(),
                          errorText: _coordinateError,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _longitude,
                        onChanged: (_) => setState(() {
                          _selected = false;
                          _coordinateError = null;
                        }),
                        decoration: const InputDecoration(
                          labelText: 'Долгота',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    final lat = double.tryParse(
                      _latitude.text.replaceAll(',', '.'),
                    );
                    final lon = double.tryParse(
                      _longitude.text.replaceAll(',', '.'),
                    );
                    if (lat == null ||
                        lon == null ||
                        !lat.isFinite ||
                        !lon.isFinite ||
                        !_inBounds(lat, lon)) {
                      setState(() => _coordinateError = 'Проверьте координаты');
                      return;
                    }
                    _select(lat, lon);
                    setState(() {
                      _centerLat = lat;
                      _centerLon = lon;
                    });
                  },
                  child: const Text('Показать координаты на карте'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      AppSecondaryButton(
        text: 'Отмена',
        onPressed: () => Navigator.pop(context),
      ),
      AppPrimaryButton(
        text: 'Подтвердить местоположение',
        onPressed: !_selected
            ? null
            : () => Navigator.pop(context, (
                latitude: _lat,
                longitude: _lon,
                manual: _manual,
              )),
      ),
    ],
  );
}
