import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_exception.dart';
import '../state/techcafe_state.dart';

class StockEditor extends StatelessWidget {
  const StockEditor({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.inventory_2_outlined, size: 18),
    label: Text(
      product.stockRemaining == null
          ? 'Остаток: без лимита'
          : 'Свободно: ${product.stockRemaining} порц.',
    ),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => _StockDialog(product: product),
    ),
  );
}

class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.product});
  final Product product;
  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  late final _value = TextEditingController(
    text: widget.product.stockRemaining?.toString() ?? '',
  );
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _value.text.trim();
    final remaining = int.tryParse(raw);
    if (raw.isNotEmpty && (remaining == null || remaining < 0)) {
      setState(() => _error = 'Введите целое число от 0.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<TechCafeState>().setProductStock(
        widget.product.id,
        remaining,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Не удалось сохранить остаток.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product.name),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Свободные порции, без уже зарезервированных. Пустое поле — без лимита. При отмене резерв возвращается.',
        ),
        TextField(
          controller: _value,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Свободных порций',
            errorText: _error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: const Text('Сохранить'),
      ),
    ],
  );
}
