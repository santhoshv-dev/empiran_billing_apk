import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/invoice_pdf_service.dart';
import '../../../../models.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';

void showDocumentPreviewDialog(
  BuildContext context,
  BusinessTransaction transaction, {
  bool isThermal = false,
}) {
  final settingsState = context.read<SettingsBloc>().state;
  final company = settingsState is SettingsLoaded ? settingsState.company : Company();

  showDialog(
    context: context,
    builder: (ctx) {
      bool thermal = isThermal;
      final screenSize = MediaQuery.sizeOf(ctx);
      return StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: thermal ? 620 : 920,
              maxHeight: screenSize.height * 0.92,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isCompact = headerConstraints.maxWidth < 460;
                      if (isCompact) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  thermal ? Icons.receipt_long : Icons.description_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    thermal ? 'Thermal Receipt (80mm)' : 'Tax Invoice (A4)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('A4', style: TextStyle(fontSize: 12)),
                                    icon: Icon(Icons.print_outlined, size: 14),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('80mm', style: TextStyle(fontSize: 12)),
                                    icon: Icon(Icons.receipt_long, size: 14),
                                  ),
                                ],
                                selected: {thermal},
                                onSelectionChanged: (set) => setState(() => thermal = set.first),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  thermal ? Icons.receipt_long : Icons.description_outlined,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    thermal ? 'Thermal Receipt (80mm)' : 'Tax Invoice (A4)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('A4'),
                                    icon: Icon(Icons.print_outlined, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('80mm'),
                                    icon: Icon(Icons.receipt_long, size: 16),
                                  ),
                                ],
                                selected: {thermal},
                                onSelectionChanged: (set) => setState(() => thermal = set.first),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    key: ValueKey(thermal),
                    build: (_) => thermal
                        ? buildThermalReceiptPdf(company, transaction)
                        : buildInvoicePdf(company, transaction),
                    canChangePageFormat: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
