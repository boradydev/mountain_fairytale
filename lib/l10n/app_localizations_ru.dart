// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Горная сказка';

  @override
  String get deliveryCardTitleToday => 'Доставка на сегодня';

  @override
  String get deliveryCardTitle => 'Доставка на';

  @override
  String get deliveryCardClients => 'Клиенты';

  @override
  String get deliveryCardClientsMetrics => 'Точек';

  @override
  String get deliveryCardBottles => 'Бутылки';

  @override
  String get deliveryCardBottlesMetrics => 'шт.';

  @override
  String get deliveryCardReturns => 'Возвраты';

  @override
  String get deliveryCardReturnsMetrics => 'шт.';

  @override
  String get deliveryCardGlasses => 'Стаканы';

  @override
  String get deliveryCardGlassesMetrics => 'шт.';

  @override
  String get deliveryCardWaterCooler => 'Кулер';

  @override
  String get deliveryCardWaterCoolerMetrics => 'шт.';

  @override
  String get deliveryCardCoolerRepair => 'Ремонт кулера';

  @override
  String get deliveryCardCoolerRepairMetrics => 'шт.';

  @override
  String get deliveryCardTotal => 'Всего';

  @override
  String get deliveryCardTotalMetrics => '₽';

  @override
  String get notifySaveSuccess => 'Файл успешно сохранен';

  @override
  String get notifySaveError => 'Ошибка сохранения файла';

  @override
  String get notifyWarning => 'Внимание: суммы в документах различаются!';

  @override
  String get notifyMergeSuccess => 'Данные из 1с УПД перенесены';

  @override
  String get resetButton => 'Сбросить';

  @override
  String get themBottom => 'Тема';
}
