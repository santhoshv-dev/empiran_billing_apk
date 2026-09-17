import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/core/utils/formatters.dart';
import 'package:empiran/core/widgets/empiran_components.dart';
import 'package:empiran/features/invoices/presentation/bloc/invoices_bloc.dart';
import 'package:empiran/features/invoices/presentation/bloc/invoices_event.dart';
import 'package:empiran/features/products/presentation/bloc/products_bloc.dart';
import 'package:empiran/features/products/presentation/bloc/products_event.dart';
import 'package:empiran/models.dart';

void showProductReturnDialog(BuildContext context, BusinessTransaction order) {
  showDialog(
    context: context,
    builder: (ctx) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<ProductsBloc>()),
        BlocProvider.value(value: context.read<InvoicesBloc>()),
      ],
      child: _ProductReturnDialog(order: order),
    ),
  );
}

class _ProductReturnDialog extends StatefulWidget {
  final BusinessTransaction order;

  const _ProductReturnDialog({required this.order});

  @override
  State<_ProductReturnDialog> createState() => _ProductReturnDialogState();
}

class _ProductReturnDialogState extends State<_ProductReturnDialog> {
  InvoiceLine? _selectedLine;
  double _returnQuantity = 1;
  final _reasonController = TextEditingController(text: 'Customer Return');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final eligible = widget.order.lines.where((l) => l.quantity > 0).toList();
    if (eligible.isNotEmpty) {
      _selectedLine = eligible.first;
      _returnQuantity = 1.clamp(1, _selectedLine!.quantity.toInt()).toDouble();
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _processReturn() async {
    final line = _selectedLine;
    if (line == null || _returnQuantity <= 0) return;

    setState(() => _busy = true);

    try {
      // 1. Calculate return and refund amounts
      final returnItemSubtotal = line.price * _returnQuantity;
      final returnTax = widget.order.isGst ? (returnItemSubtotal * 0.18) : 0.0;
      final totalRefundAmount = returnItemSubtotal + returnTax;

      // 2. Restore product stock in catalog (supports itemId or name fallback)
      await context.read<ProductsBloc>().productsRepository.adjustStockById(
            line.itemId,
            _returnQuantity,
            itemName: line.name,
            reason: 'Return from Order #${widget.order.number}: ${_reasonController.text.trim()}',
          );
      if (mounted) {
        context.read<ProductsBloc>().add(const LoadProductsRequested());
      }

      // 3. Update order line items
      final updatedLines = widget.order.lines.map((l) {
        final matches = (l.itemId.isNotEmpty && l.itemId != 'null' && l.itemId == line.itemId) ||
            (l.name.trim().toLowerCase() == line.name.trim().toLowerCase());
        if (matches) {
          final newQty = (l.quantity - _returnQuantity).clamp(0, double.infinity);
          return InvoiceLine(
            itemId: l.itemId,
            name: l.name,
            quantity: newQty.toDouble(),
            unit: l.unit,
            price: l.price,
            hsn: l.hsn,
          );
        }
        return InvoiceLine.fromJson(l.toJson());
      }).where((l) => l.quantity > 0).toList();

      // Adjust paid amount if customer paid
      final newPaid = widget.order.paid > 0
          ? (widget.order.paid - totalRefundAmount).clamp(0, double.infinity).toDouble()
          : 0.0;

      final updatedOrder = BusinessTransaction(
        id: widget.order.id,
        type: widget.order.type,
        number: widget.order.number,
        date: widget.order.date,
        lines: updatedLines,
        partyId: widget.order.partyId,
        partyName: widget.order.partyName,
        partyPhone: widget.order.partyPhone,
        partyAddress: widget.order.partyAddress,
        partyGstin: widget.order.partyGstin,
        isGst: widget.order.isGst,
        paid: newPaid,
        paymentMode: widget.order.paymentMode,
        status: updatedLines.isEmpty ? 'Returned' : widget.order.status,
        dispatch: widget.order.dispatch,
        discount: widget.order.discount,
        shipping: widget.order.shipping,
        notes: '${widget.order.notes}\n[Returned ${_returnQuantity.toInt()}x ${line.name} (Refund: ${Formatters.money(totalRefundAmount)}) on ${Formatters.date(DateTime.now())}]'.trim(),
        referredBy: widget.order.referredBy,
        convertedFrom: widget.order.convertedFrom,
      );

      if (mounted) {
        context.read<InvoicesBloc>().add(SaveTransactionRequested(updatedOrder));
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Returned ${_returnQuantity.toInt()}x ${line.name}. Refund: ${Formatters.money(totalRefundAmount)}. Stock restored!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error returning product: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibleLines = widget.order.lines.where((l) => l.quantity > 0).toList();
    final returnSubtotal = _selectedLine != null ? (_selectedLine!.price * _returnQuantity) : 0.0;
    final returnTax = widget.order.isGst ? (returnSubtotal * 0.18) : 0.0;
    final totalRefund = returnSubtotal + returnTax;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment_return_outlined, color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Product Return', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Order #${widget.order.number}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: eligibleLines.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('All products in this order have already been returned or cancelled.'),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'If a customer returns a particular product, select it below. Its stock will be restored automatically to the inventory.',
                      style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<InvoiceLine>(
                      initialValue: _selectedLine,
                      decoration: const InputDecoration(
                        labelText: 'Select Product to Return',
                        border: OutlineInputBorder(),
                      ),
                      items: eligibleLines.map((l) {
                        return DropdownMenuItem(
                          value: l,
                          child: Text('${l.name} (${l.quantity.toInt()} ${l.unit} @ ${Formatters.money(l.price)})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedLine = val;
                            _returnQuantity = 1.clamp(1, val.quantity.toInt()).toDouble();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_selectedLine != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Return Quantity (Max: ${_selectedLine!.quantity.toInt()}):',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 16),
                                  onPressed: _returnQuantity > 1
                                      ? () => setState(() => _returnQuantity--)
                                      : null,
                                ),
                                Text(
                                  '${_returnQuantity.toInt()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: _returnQuantity < _selectedLine!.quantity
                                      ? () => setState(() => _returnQuantity++)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      EmpiranTextField(
                        controller: _reasonController,
                        label: 'Return Reason (Optional)',
                        hint: 'e.g. Defective item, customer changed mind',
                        prefixIcon: Icons.notes_outlined,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Return Item Total:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(Formatters.money(returnSubtotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            if (widget.order.isGst) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('GST (18%):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(Formatters.money(returnTax), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Refund / Return Amount:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                Text(
                                  Formatters.money(totalRefund),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '+${_returnQuantity.toInt()} ${_selectedLine!.unit} will be added back automatically to catalog stock.',
                                style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (eligibleLines.isNotEmpty)
          EmpiranButton(
            label: 'Confirm Return (${Formatters.money(totalRefund)})',
            icon: Icons.assignment_return_outlined,
            isLoading: _busy,
            onPressed: _processReturn,
          ),
      ],
    );
  }
}
