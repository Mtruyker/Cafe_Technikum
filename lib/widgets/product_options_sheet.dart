import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import '../utils/formatters.dart';

class ProductOptionsSheet extends StatefulWidget {
  const ProductOptionsSheet({super.key, required this.product});

  final Product product;

  @override
  State<ProductOptionsSheet> createState() => _ProductOptionsSheetState();
}

class _ProductOptionsSheetState extends State<ProductOptionsSheet> {
  static const _noSelectionValue = '__no_selection__';
  late final Map<String, List<ModifierItem>> _selectedByGroup;

  @override
  void initState() {
    super.initState();

    _selectedByGroup = {
      for (final group in widget.product.modifierGroups)
        group.id: group.min > 0 && group.items.isNotEmpty
            ? [group.items.first]
            : <ModifierItem>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final previewTotal = _previewTotal;
    final selectedModifiersTotal = _selectedModifiersTotal;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(widget.product.description),
                const SizedBox(height: AppSpacing.sm),
                _PricePreviewCard(
                  basePrice: widget.product.price,
                  modifiersTotal: selectedModifiersTotal,
                  total: previewTotal,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (widget.product.modifierGroups.isEmpty)
                  const Text('Опции не заданы. Товар будет добавлен как есть.'),
                ...widget.product.modifierGroups.map(_buildGroupSection),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(
                      'Добавить в корзину • ${formatRub(previewTotal)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSection(ModifierGroup group) {
    final selected = _selectedByGroup[group.id] ?? const <ModifierItem>[];
    final groupValue = selected.isEmpty ? null : selected.first.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${group.name}${group.min > 0 ? ' *' : ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _groupRequirementLabel(group, selected.length),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (group.max <= 1) ...[
            RadioGroup<String>(
              groupValue: group.min == 0 && groupValue == null
                  ? _noSelectionValue
                  : groupValue,
              onChanged: (value) {
                setState(() {
                  if (value == null || value == _noSelectionValue) {
                    _selectedByGroup[group.id] = <ModifierItem>[];
                    return;
                  }

                  final next = group.items.firstWhere(
                    (entry) => entry.id == value,
                  );
                  _selectedByGroup[group.id] = <ModifierItem>[next];
                });
              },
              child: Column(
                children: [
                  if (group.min == 0)
                    const RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: _noSelectionValue,
                      title: Text('Без выбора'),
                      subtitle: Text('Без доплаты'),
                    ),
                  ...group.items.map(
                    (item) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: item.id,
                      title: Text(item.name),
                      subtitle: Text(_priceDeltaLabel(item.priceDelta)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...group.items.map((item) {
              final isChecked = selected.any(
                (selectedItem) => selectedItem.id == item.id,
              );
              final canCheck = isChecked || selected.length < group.max;

              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: isChecked,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: canCheck
                    ? (checked) {
                        if (checked == null) {
                          return;
                        }

                        setState(() {
                          final next = [...selected];
                          if (checked) {
                            next.add(item);
                          } else {
                            next.removeWhere((entry) => entry.id == item.id);
                          }
                          _selectedByGroup[group.id] = next;
                        });
                      }
                    : null,
                title: Text(item.name),
                subtitle: Text(_priceDeltaLabel(item.priceDelta)),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _submit() {
    for (final group in widget.product.modifierGroups) {
      final selected = _selectedByGroup[group.id] ?? const <ModifierItem>[];
      if (selected.length < group.min) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Выберите опцию: ${group.name}')),
        );
        return;
      }
      if (selected.length > group.max) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Слишком много опций в ${group.name}')),
        );
        return;
      }
    }

    final modifiers = _selectedByGroup.values
        .expand((items) => items)
        .map(
          (item) =>
              SelectedModifier(name: item.name, priceDelta: item.priceDelta),
        )
        .toList(growable: false);

    Navigator.of(context).pop(modifiers);
  }

  double get _selectedModifiersTotal => _selectedByGroup.values
      .expand((items) => items)
      .fold<double>(0, (sum, item) => sum + item.priceDelta);

  double get _previewTotal => widget.product.price + _selectedModifiersTotal;

  String _groupRequirementLabel(ModifierGroup group, int selectedCount) {
    final selectionText = group.max <= 1
        ? 'Выбрано: ${selectedCount == 0 ? 'без выбора' : '1'}'
        : 'Выбрано: $selectedCount из ${group.max}';

    final ruleText = switch ((group.min, group.max)) {
      (0, 1) => 'Необязательно, можно выбрать не более одной опции',
      (_, _) when group.min == group.max => 'Нужно выбрать ${group.min}',
      (0, _) => 'Можно выбрать до ${group.max}',
      _ => 'Выберите от ${group.min} до ${group.max}',
    };

    return '$ruleText. $selectionText.';
  }

  String _priceDeltaLabel(double delta) {
    if (delta == 0) {
      return 'Без доплаты';
    }
    if (delta > 0) {
      return '+ ${formatRub(delta)}';
    }
    return '- ${formatRub(delta.abs())}';
  }
}

class _PricePreviewCard extends StatelessWidget {
  const _PricePreviewCard({
    required this.basePrice,
    required this.modifiersTotal,
    required this.total,
  });

  final double basePrice;
  final double modifiersTotal;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Предварительная цена', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            _PricePreviewRow(
              label: 'Базовая цена',
              value: formatRub(basePrice),
            ),
            const SizedBox(height: AppSpacing.xxs),
            _PricePreviewRow(
              label: 'Опции',
              value: modifiersTotal == 0
                  ? 'Без доплаты'
                  : modifiersTotal > 0
                  ? '+ ${formatRub(modifiersTotal)}'
                  : '- ${formatRub(modifiersTotal.abs())}',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Divider(height: 1),
            ),
            _PricePreviewRow(
              label: 'Итого',
              value: formatRub(total),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PricePreviewRow extends StatelessWidget {
  const _PricePreviewRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = emphasize
        ? theme.textTheme.titleLarge
        : theme.textTheme.bodyMedium;

    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: valueStyle),
      ],
    );
  }
}
