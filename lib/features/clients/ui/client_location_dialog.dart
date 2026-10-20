import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:flutter/gestures.dart';
import 'package:mountain_fairytale/features/clients/data/location_repository.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/geo_attribution.dart';

Future<DeliveryAddress?> showClientLocationDialog(
  BuildContext context, {
  required LocationRepository repository,
  required String address,
  List<LocationCandidate> candidates = const [],
  DeliveryAddress? existing,
}) => showDialog<DeliveryAddress>(
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _district, _locality, _street, _house;
  late List<LocationCandidate> _candidates;
  bool _searching = false;
  String? _searchError;
  Map<String, String> get _parts => {
    'district': _district.text.trim(),
    'locality': _locality.text.trim(),
    'street': _street.text.trim(),
    'house': _house.text.trim(),
  };
  Future<void> _search() async {
    if (_searching || !_formKey.currentState!.validate()) return;
    setState(() {
      _searching = true;
      _searchError = null;
      _selected = false;
      _candidates = [];
    });
    try {
      final candidates = await widget.repository.search(_parts);
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        final c = candidates.firstOrNull;
        if (c != null) {
          _lat = _centerLat = c.latitude;
          _lon = _centerLon = c.longitude;
          _selected = c.exactHouse;
          _manual = false;
          _zoom = c.exactHouse ? 17 : 15;
          _syncCoordinates();
        } else {
          _searchError =
              'Адрес не найден. Уточните поля или укажите место вручную.';
        }
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _searchError = error is ApiException ? error.message : 'Поиск недоступен. Можно указать координаты вручную или сохранить клиента без подтверждения.',
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Widget _part(
    TextEditingController controller,
    String label,
    int maxLength, {
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: !_searching,
      maxLength: maxLength,
      validator: (value) =>
          required && (value?.trim().isEmpty ?? true) ? 'Заполните поле' : null,
      onChanged: (_) => setState(() {
        _selected = false;
        _candidates = [];
        _searchError = null;
      }),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  late double _lat, _lon, _centerLat, _centerLon;
  int _zoom = 17;
  bool _selected = false, _manual = false;
  String? _coordinateError;
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  int _gestureZoom = 17;
  @override
  void initState() {
    super.initState();
    _candidates = widget.candidates;
    _district = TextEditingController(text: widget.existing?.district ?? '');
    _locality = TextEditingController(text: widget.existing?.locality ?? '');
    _street = TextEditingController(text: widget.existing?.street ?? '');
    _house = TextEditingController(text: widget.existing?.house ?? '');
    final c = _candidates.firstOrNull;
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
    for (final c in [_district, _locality, _street, _house]) {
      c.dispose();
    }
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

  void _centerFromWorld(Offset point) {
    final p = _unproject(point);
    _centerLat = p.lat.clamp(43.4, 46.6);
    _centerLon = p.lon.clamp(40.8, 45.9);
  }

  void _zoomAt(int level, Offset focalPoint, Size size) {
    final next = level.clamp(8, 19);
    if (next == _zoom) return;
    final offset = focalPoint - Offset(size.width / 2, size.height / 2);
    final anchor = _project(_centerLat, _centerLon) + offset;
    final factor = math.pow(2, next - _zoom).toDouble();
    _zoom = next;
    _centerFromWorld(anchor * factor - offset);
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.address),
              const SizedBox(height: 8),
              _part(
                _district,
                'Район / муниципальный или городской округ',
                150,
                required: false,
              ),
              _part(_locality, 'Населённый пункт (с типом) *', 150),
              _part(_street, 'Улица (с типом) *', 150),
              _part(_house, 'Дом *', 40),
              AppSecondaryButton(
                text: _searching ? 'Поиск…' : 'Найти адрес',
                onPressed: _searching ? null : _search,
              ),
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _searchError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_candidates.isNotEmpty)
                Text('Найдено: ${_candidates.first.formatted}'),
              const Text(
                'Проверьте дом и место подъезда. Можно выбрать место на карте или ввести координаты.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Масштаб: колёсико мыши, жест двумя пальцами или кнопки +/−. Перетащите карту или метку к нужному въезду.',
              ),
              const SizedBox(height: 8),
              SizedBox(
                key: const ValueKey('client-location-map'),
                height: 360,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final center = _project(_centerLat, _centerLon);
                    final size = Size(constraints.maxWidth, 360);
                    final origin =
                        center - Offset(size.width / 2, size.height / 2);
                    final tx = (origin.dx / 256).floor(),
                        ty = (origin.dy / 256).floor();
                    final marker = _project(_lat, _lon) - origin;
                    return ClipRect(
                      child: Listener(
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent &&
                              event.scrollDelta.dy != 0) {
                            GestureBinding.instance.pointerSignalResolver
                                .register(event, (_) {
                                  setState(
                                    () => _zoomAt(
                                      _zoom +
                                          (event.scrollDelta.dy < 0 ? 1 : -1),
                                      event.localPosition,
                                      size,
                                    ),
                                  );
                                });
                          }
                        },
                        child: GestureDetector(
                          trackpadScrollCausesScale: true,
                          onTapUp: (e) {
                            final p = _unproject(origin + e.localPosition);
                            _select(p.lat, p.lon);
                          },
                          onScaleStart: (_) => _gestureZoom = _zoom,
                          onScaleUpdate: (event) => setState(() {
                            final level =
                                (_gestureZoom +
                                        math.log(event.scale) / math.ln2)
                                    .round();
                            _zoomAt(level, event.localFocalPoint, size);
                            _centerFromWorld(
                              _project(_centerLat, _centerLon) -
                                  event.focalPointDelta,
                            );
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
                                    y <=
                                        ((origin.dy + size.height) / 256)
                                            .floor();
                                    y++
                                  )
                                    Positioned(
                                      left: x * 256 - origin.dx,
                                      top: y * 256 - origin.dy,
                                      width: 256,
                                      height: 256,
                                      child: FutureBuilder<Uint8List>(
                                        future: widget.repository.tile(
                                          _zoom,
                                          x,
                                          y,
                                        ),
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
                                            ? () => setState(
                                                () => _zoomAt(
                                                  _zoom + 1,
                                                  Offset(
                                                    size.width / 2,
                                                    size.height / 2,
                                                  ),
                                                  size,
                                                ),
                                              )
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
                                            ? () => setState(
                                                () => _zoomAt(
                                                  _zoom - 1,
                                                  Offset(
                                                    size.width / 2,
                                                    size.height / 2,
                                                  ),
                                                  size,
                                                ),
                                              )
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
                        setState(
                          () => _coordinateError = 'Проверьте координаты',
                        );
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
    ),
    actions: [
      AppSecondaryButton(
        text: 'Отмена',
        onPressed: () => Navigator.pop(context),
      ),
      AppPrimaryButton(
        text: 'Подтвердить местоположение',
        onPressed: !_selected || _searching
            ? null
            : () {
                if (!_formKey.currentState!.validate()) return;
                final result = DeliveryAddress(
                  district: _parts['district']!,
                  locality: _parts['locality']!,
                  street: _parts['street']!,
                  house: _parts['house']!,
                  latitude: _lat,
                  longitude: _lon,
                  source: _manual ? 'manual' : 'geoapify',
                );
                if (result.formatted.length > 500) {
                  setState(
                    () => _searchError =
                        'Полный адрес не должен превышать 500 символов',
                  );
                  return;
                }
                Navigator.pop(context, result);
              },
      ),
    ],
  );
}
