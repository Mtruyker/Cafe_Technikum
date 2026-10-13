import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_exception.dart';
import '../state/techcafe_state.dart';

String pickupTimeLabel(DateTime time) {
  // Cafe schedule is Europe/Saratov (UTC+4), independent of device timezone.
  final t = time.toUtc().add(const Duration(hours: 4));
  return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class PickupSlotPicker extends StatefulWidget {
  const PickupSlotPicker({
    super.key,
    required this.portions,
    required this.onChanged,
  });
  final int portions;
  final ValueChanged<String?> onChanged;
  @override
  State<PickupSlotPicker> createState() => _PickupSlotPickerState();
}

class _PickupSlotPickerState extends State<PickupSlotPicker> {
  List<PickupSlot> _slots = [];
  String? _selected;
  String? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PickupSlotPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.portions != widget.portions) {
      _selected = null;
      widget.onChanged(null);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
    });
    widget.onChanged(null);
    try {
      final slots = await context.read<TechCafeState>().fetchPickupSlots();
      if (mounted) setState(() => _slots = slots);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Не удалось загрузить время получения.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _slots
        .where((s) => s.fits(widget.portions, DateTime.now()))
        .toList();
    final unavailableMessage = _slots.isEmpty
        ? 'Расписание получения пока не опубликовано. Обратитесь к сотруднику кафе.'
        : 'Нет доступного времени для этого заказа: приём закрыт или недостаточно свободных порций.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Получение к перемене (время кафе, UTC+4)'),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              tooltip: 'Обновить время',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (!_loading && _error == null && available.isEmpty)
          Text(unavailableMessage),
        DropdownButtonFormField<String>(
          key: ValueKey('${widget.portions}:$_selected:${_slots.hashCode}'),
          initialValue: available.any((s) => s.id == _selected)
              ? _selected
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Время получения *',
            border: OutlineInputBorder(),
          ),
          items: available
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(
                    '${pickupTimeLabel(s.startsAt)} · ${s.remaining} порц.',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _loading || _error != null || available.isEmpty
              ? null
              : (value) {
                  setState(() => _selected = value);
                  widget.onChanged(value);
                },
          validator: (value) {
            if (_loading) return 'Дождитесь загрузки времени получения';
            if (_error != null) {
              return 'Не удалось загрузить расписание. Нажмите «Обновить время».';
            }
            if (available.isEmpty) return unavailableMessage;
            return value == null || !available.any((s) => s.id == value)
                ? 'Выберите доступное время получения'
                : null;
          },
        ),
        if (_slots.length > available.length)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Переполненные и закрытые слоты исключены. Показаны доступные альтернативы.',
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
