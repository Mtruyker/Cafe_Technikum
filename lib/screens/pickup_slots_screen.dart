import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_exception.dart';
import '../state/techcafe_state.dart';
import '../widgets/pickup_slot_picker.dart';

class PickupSlotsScreen extends StatefulWidget {
  const PickupSlotsScreen({super.key});
  @override
  State<PickupSlotsScreen> createState() => _PickupSlotsScreenState();
}

class _PickupSlotsScreenState extends State<PickupSlotsScreen> {
  List<PickupSlot> _slots = [];
  bool _busy = false;
  String? _error;
  String? _result;
  final _capacity = TextEditingController(text: '30');
  DateTime _date = DateTime.now().toUtc().add(const Duration(hours: 4));
  @override
  void initState() {
    super.initState();
    _run(_reload);
  }

  @override
  void dispose() {
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final slots = await context.read<TechCafeState>().fetchPickupSlots(
      admin: true,
    );
    if (mounted) setState(() => _slots = slots);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Не удалось сохранить расписание.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createDay() async {
    final capacity = int.tryParse(_capacity.text);
    if (capacity == null || capacity < 1) {
      setState(() => _error = 'Введите положительный лимит порций.');
      return;
    }
    final state = context.read<TechCafeState>();
    await _run(() async {
      await _reload();
      var added = 0;
      var closed = 0;
      var existing = 0;
      for (final (hour, minute) in [(10, 0), (11, 40), (13, 40)]) {
        final start = DateTime.utc(
          _date.year,
          _date.month,
          _date.day,
          hour,
          minute,
        ).subtract(const Duration(hours: 4));
        if (!start
            .subtract(const Duration(minutes: 5))
            .isAfter(DateTime.now())) {
          closed++;
          continue;
        }
        if (_slots.any((s) => s.startsAt.isAtSameMomentAs(start))) {
          existing++;
          continue;
        }
        await state.savePickupSlot(
          startsAt: start,
          cutoffAt: start.subtract(const Duration(minutes: 5)),
          capacity: capacity,
        );
        added++;
      }
      await _reload();
      if (mounted) {
        setState(() {
          _result = added > 0
              ? 'Добавлено перемен: $added. Уже существовали: $existing. Приём закрыт: $closed.'
              : closed == 3
              ? 'На выбранную дату приём заказов на все перемены уже закрыт. Выберите следующую дату.'
              : 'Новых перемен нет: доступные перемены на эту дату уже добавлены. Проверьте их переключатели ниже. Приём закрыт: $closed.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Расписание и загрузка кухни'),
      actions: [
        IconButton(
          onPressed: _busy ? null : () => _run(_reload),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Перемены: 10:00–10:10, 11:40–12:10, 13:40–13:50. Время кафе: UTC+4. Заказ готовится к началу перемены. Приём закрывается за 5 минут.',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  final now = DateTime.now().toUtc().add(
                    const Duration(hours: 4),
                  );
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: now.add(const Duration(days: 90)),
                  );
                  if (date != null && mounted) setState(() => _date = date);
                },
          child: Text('Дата: ${_date.day}.${_date.month}.${_date.year}'),
        ),
        TextField(
          controller: _capacity,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Лимит порций на каждую перемену',
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : _createDay,
          child: const Text('Добавить перемены на дату'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_result!, semanticsLabel: _result),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (!_busy && _slots.isEmpty)
          const Text(
            'Расписание пока пусто. Добавьте перемены для приёма заказов.',
          ),
        ..._slots.map(
          (s) => Card(
            child: ListTile(
              title: Text(pickupTimeLabel(s.startsAt)),
              subtitle: Text(
                'Занято ${s.capacity - s.remaining} из ${s.capacity} порций\nПриём до ${pickupTimeLabel(s.cutoffAt)}',
              ),
              trailing: Switch(
                value: s.enabled,
                onChanged: _busy
                    ? null
                    : (enabled) => _run(() async {
                        await context.read<TechCafeState>().savePickupSlot(
                          id: s.id,
                          startsAt: s.startsAt,
                          cutoffAt: s.cutoffAt,
                          capacity: s.capacity,
                          enabled: enabled,
                        );
                        await _reload();
                      }),
              ),
              onTap: _busy
                  ? null
                  : () async {
                      var capacityText = '${s.capacity}';
                      final value = await showDialog<int>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Лимит порций'),
                          content: TextFormField(
                            initialValue: capacityText,
                            onChanged: (value) => capacityText = value,
                            keyboardType: TextInputType.number,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Отмена'),
                            ),
                            FilledButton(
                              onPressed: () {
                                final n = int.tryParse(capacityText);
                                if (n != null && n > 0) Navigator.pop(ctx, n);
                              },
                              child: const Text('Сохранить'),
                            ),
                          ],
                        ),
                      );
                      if (value != null && mounted) {
                        await _run(() async {
                          await context.read<TechCafeState>().savePickupSlot(
                            id: s.id,
                            startsAt: s.startsAt,
                            cutoffAt: s.cutoffAt,
                            capacity: value,
                            enabled: s.enabled,
                          );
                          await _reload();
                        });
                      }
                    },
            ),
          ),
        ),
      ],
    ),
  );
}
