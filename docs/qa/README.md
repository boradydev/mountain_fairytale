# QA-приёмка Flutter Windows

**Единая QA-стратегия хранится в backend:**  
[docs/qa/README.md — шесть этапов](https://github.com/boradydev/mountain_fairytale_backend/blob/codex/delivery-history/docs/qa/README.md).

**Текущий статус и журнал дефектов:**  
[backend/docs/qa/progress.md](https://github.com/boradydev/mountain_fairytale_backend/blob/codex/delivery-history/docs/qa/progress.md).

**Реестр выполненных требований заказчика:**  
[client-requirements-completion-2026-11.md](https://github.com/boradydev/mountain_fairytale_backend/blob/codex/delivery-history/docs/contracts/client-requirements-completion-2026-11.md).

## Роль Flutter в QA-наборе

- Оператор запускает настоящий Flutter Windows и выполняет согласованные
  пошаговые сценарии из backend `docs/qa/scenarios/`.
- Flutter подключается **только к специально подготовленному QA API**,
  адрес которого подтверждён перед тестированием через
  «Приложение → Настройки подключения».
- Оператор проверяет UX, темы, визуальную компоновку, сообщения, поведение
  при длительных операциях и печатные формы.
- Backend QA-проверяющий независимо сверяет сохранённые данные, денежные
  расчёты, комиссию, историю и аудит через API и/или PostgreSQL.
- Автоматическая сверка данных не заменяет ручную оценку внешнего вида и PDF.
- Существующие `test/` и `test/live/` использовать там, где подходят,
  без дублирования сценариев. Live-тесты создают записи: **не запускать
  против production или неизвестного сервера**.
- При ошибках фиксировать сценарий, ожидаемое и фактическое поведение;
  после исправления добавлять регрессионный тест.

## Статус

На 10.11.2026 этапы 1–5 и блоки 6.1–6.3 приняты владельцем.
**Финальный блок 6.4 на проверке владельцем:** настоящий Windows Release
`1.3.0+104` с изолированным реальным API/PostgreSQL, GUI/SQL smoke и
сохранением сессии при точном Release→Release restart прошли проверки.
[Итоговый отчёт, матрица этапов и рекомендация GO](https://github.com/boradydev/mountain_fairytale_backend/blob/codex/delivery-history/docs/qa/reports/2026-11-10-stage-6-block-4.md).

На ПК разработки оставлена закрытая тестовая Release с loopback API и
выключенным updater; это не production-дистрибутив. N6-01 и границы native
A→B auth/Release HTTPS/исторического сбоя отражены в итоговом отчёте.
Этот файл остаётся указателем на единую backend QA-стратегию.
Приёмка всего этапа 6 и решение о выпуске — только владельцем;
публикация, merge и production deploy не выполнялись.
