import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../../../../models.dart';
import '../bloc/products_bloc.dart';
import '../bloc/products_event.dart';

void showStockAdjustDialog(BuildContext context, Item item) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<ProductsBloc>(),
      child: _StockAdjustDialog(item: item),
    ),
  );
}

class _StockAdjustDialog extends StatefulWidget {
  const _StockAdjustDialog({required this.item});
  final Item item;

  @override
  State<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<_StockAdjustDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text);
    if (value == null || !value.isFinite) {
      setState(() => _error = 'Enter a valid quantity number.');
      return;
    }
    context.read<ProductsBloc>().add(AdjustStockRequested(item: widget.item, change: value));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Adjust Stock — ${widget.item.name}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Available Stock: ${widget.item.currentStock} ${widget.item.unit}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter positive quantity to add stock, or negative to reduce stock.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            EmpiranTextField(
              controller: _controller,
              label: 'Adjustment Quantity',
              hint: 'e.g. +10 or -5',
              isNumber: true,
              isDecimal: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
          ],
        ),
      ),
    ),
    actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        EmpiranButton(
          label: 'Update Stock',
          onPressed: _submit,
        ),
      ],
    );
  }
}
