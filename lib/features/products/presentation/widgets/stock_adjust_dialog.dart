import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../../../../models.dart';
import '../bloc/products_bloc.dart';
import '../bloc/products_event.dart';

void showStockAdjustDialog(BuildContext context, Item item) {
  final controller = TextEditingController();
  String? error;

  showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text('Adjust Stock — ${item.name}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Available Stock: ${item.currentStock} ${item.unit}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter positive quantity to add stock, or negative to reduce stock.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              EmpiranTextField(
                controller: controller,
                label: 'Adjustment Quantity',
                hint: 'e.g. +10 or -5',
                isNumber: true,
                isDecimal: true,
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          EmpiranButton(
            label: 'Update Stock',
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value == null || !value.isFinite) {
                set(() => error = 'Enter a valid quantity number.');
                return;
              }
              context.read<ProductsBloc>().add(AdjustStockRequested(item: item, change: value));
              Navigator.pop(c);
            },
          ),
        ],
      ),
    ),
  );

  Future.delayed(const Duration(milliseconds: 500), () => controller.dispose());
}
