import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../../../../models.dart';
import '../bloc/products_bloc.dart';
import 'stock_adjust_dialog.dart';

void showStockHistoryDialog(BuildContext context, Item item) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<ProductsBloc>(),
      child: _StockHistoryDialog(item: item),
    ),
  );
}

class _StockHistoryDialog extends StatefulWidget {
  const _StockHistoryDialog({required this.item});
  final Item item;

  @override
  State<_StockHistoryDialog> createState() => _StockHistoryDialogState();
}

class _StockHistoryDialogState extends State<_StockHistoryDialog> {
  List<StockRecord>? _history;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final repo = context.read<ProductsBloc>().productsRepository;
    final records = await repo.getStockHistory(widget.item.id);
    if (mounted) {
      setState(() {
        _history = records;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd-MMM-yyyy hh:mm a');

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Current Stock: ${widget.item.currentStock.toStringAsFixed(0)} ${widget.item.unit}',
                  style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          EmpiranButton(
            label: '+ Add Stock',
            icon: Icons.add_circle_outline,
            height: 36,
            onPressed: () {
              Navigator.pop(context);
              showStockAdjustDialog(context, widget.item);
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        height: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_history == null || _history!.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No stock adjustment history yet.', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        const Text('Stock adjustments will appear here.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _history!.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final rec = _history![i];
                      final isAdd = rec.adjustmentType == 'add';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isAdd
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.error.withValues(alpha: 0.12),
                              child: Icon(
                                isAdd ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                color: isAdd ? AppColors.success : AppColors.error,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rec.reason.isNotEmpty ? rec.reason : (isAdd ? 'Stock Added' : 'Stock Reduced'),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateFormat.format(rec.date),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isAdd ? '+' : '-'}${rec.quantity.toStringAsFixed(0)} ${widget.item.unit}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isAdd ? AppColors.success : AppColors.error,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${rec.previousStock.toStringAsFixed(0)} → ${rec.updatedStock.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
