import 'package:mountain_fairytale/infra/repos/abcs.dart';

class DemoDriverDataSource implements DriverDataSource {
  List<Map<String, dynamic>>? _driversCache;

  @override
  Future<List<Map<String, dynamic>>> getAllDrivers() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _driversCache ??= [
      {'id': 1, 'name': 'Иванов Иван Иванович'},
      {'id': 2, 'name': 'Петров Петр Петрович'},
      {'id': 3, 'name': 'Сидоров Алексей Владимирович'},
    ];
    return _driversCache!;
  }

  @override
  Future<Map<String, dynamic>> createDriver(
    Map<String, dynamic> driverJson,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_driversCache == null) await getAllDrivers();

    final newId = _driversCache!.isEmpty
        ? 1
        : _driversCache!
                  .map((item) => int.parse(item['id'].toString()))
                  .reduce((a, b) => a > b ? a : b) +
              1;

    final newDriver = {...driverJson, 'id': newId};
    _driversCache!.insert(0, newDriver);
    return newDriver;
  }
}
