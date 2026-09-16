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
      return StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: thermal ? 620 : 920,
            height: 720,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(
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
