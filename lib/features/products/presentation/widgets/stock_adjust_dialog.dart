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
  late final TextEditingController _reasonController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _reasonController = TextEditingController(text: 'Stock Addition');
  }

  @override
  void dispose() {
    _controller.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text);
    if (value == null || !value.isFinite) {
      setState(() => _error = 'Enter a valid quantity number.');
      return;
    }
    context.read<ProductsBloc>().add(
          AdjustStockRequested(
            item: widget.item,
            change: value,
            reason: _reasonController.text.trim().isEmpty
                ? (value >= 0 ? 'Stock Added' : 'Stock Reduced')
                : _reasonController.text.trim(),
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(_controller.text) ?? 0;
    final updatedStock = widget.item.currentStock + qty;

    return AlertDialog(
      title: Text(
        'Add / Adjust Stock — ${widget.item.name}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Previous Stock',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          '${widget.item.currentStock.toStringAsFixed(0)} ${widget.item.unit}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded,
                        color: AppColors.primary, size: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Updated Stock',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          '${updatedStock.toStringAsFixed(0)} ${widget.item.unit}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              EmpiranTextField(
                controller: _controller,
                label: 'Stock Quantity to Add',
                hint: 'e.g. 50 (or -10 to reduce)',
                isNumber: true,
                isDecimal: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              EmpiranTextField(
                controller: _reasonController,
                label: 'Reason / Source (Optional)',
                hint: 'e.g. Supplier Shipment, Physical Audit',
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 13)),
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
          label: 'Save Stock',
          icon: Icons.check_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}
