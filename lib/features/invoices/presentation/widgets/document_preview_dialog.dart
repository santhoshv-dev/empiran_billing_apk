import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/invoice_pdf_service.dart';
import '../../../../models.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_event.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';
import 'invoice_customization_panel.dart';

void showDocumentPreviewDialog(
  BuildContext context,
  BusinessTransaction transaction, {
  bool isThermal = false,
  bool initiallyCustomize = false,
}) {
  final settingsState = context.read<SettingsBloc>().state;
  final company =
      settingsState is SettingsLoaded ? settingsState.company : Company();
  final savedSettings = settingsState is SettingsLoaded
      ? settingsState.invoiceSettings
      : InvoiceSettings();

  showDialog(
    context: context,
    builder: (ctx) {
      bool thermal = initiallyCustomize ? false : isThermal;
      bool isFullscreen = false;
      bool customize = initiallyCustomize;
      InvoiceSettings design = savedSettings.copyWith();
      return StatefulBuilder(
        builder: (context, setState) {
          final screenSize = MediaQuery.sizeOf(context);
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isFullscreen ? 0 : 16),
            ),
            insetPadding: isFullscreen
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isFullscreen
                    ? screenSize.width
                    : (thermal
                        ? 620
                        : (screenSize.width > 1200
                            ? 1100
                            : screenSize.width * 0.95)),
                maxHeight:
                    isFullscreen ? screenSize.height : screenSize.height * 0.95,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
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
                                    thermal
                                        ? Icons.receipt_long
                                        : Icons.description_outlined,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      thermal
                                          ? 'Thermal Receipt (80mm)'
                                          : 'Tax Invoice (A4)',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      customize
                                          ? Icons.palette
                                          : Icons.palette_outlined,
                                      color:
                                          customize ? AppColors.primary : null,
                                      size: 20,
                                    ),
                                    tooltip: 'Customize Invoice',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(() {
                                      customize = !customize;
                                      if (customize) thermal = false;
                                    }),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isFullscreen
                                          ? Icons.fullscreen_exit_rounded
                                          : Icons.fullscreen_rounded,
                                      size: 20,
                                    ),
                                    tooltip: isFullscreen
                                        ? 'Exit Full Screen'
                                        : 'Full Screen',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(
                                        () => isFullscreen = !isFullscreen),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
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
                                      label: Text('A4',
                                          style: TextStyle(fontSize: 12)),
                                      icon:
                                          Icon(Icons.print_outlined, size: 14),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      label: Text('80mm',
                                          style: TextStyle(fontSize: 12)),
                                      icon: Icon(Icons.receipt_long, size: 14),
                                    ),
                                  ],
                                  selected: {thermal},
                                  onSelectionChanged: (selection) =>
                                      setState(() {
                                    thermal = selection.first;
                                    if (thermal) customize = false;
                                  }),
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
                                    thermal
                                        ? Icons.receipt_long
                                        : Icons.description_outlined,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      thermal
                                          ? 'Thermal Receipt (80mm)'
                                          : 'Tax Invoice (A4)',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
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
                                      icon:
                                          Icon(Icons.print_outlined, size: 16),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      label: Text('80mm'),
                                      icon: Icon(Icons.receipt_long, size: 16),
                                    ),
                                  ],
                                  selected: {thermal},
                                  onSelectionChanged: (selection) =>
                                      setState(() {
                                    thermal = selection.first;
                                    if (thermal) customize = false;
                                  }),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: Icon(
                                    customize
                                        ? Icons.palette
                                        : Icons.palette_outlined,
                                    color: customize ? AppColors.primary : null,
                                  ),
                                  tooltip: 'Customize Invoice',
                                  onPressed: () => setState(() {
                                    customize = !customize;
                                    if (customize) thermal = false;
                                  }),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isFullscreen
                                        ? Icons.fullscreen_exit_rounded
                                        : Icons.fullscreen_rounded,
                                    color: AppColors.primary,
                                  ),
                                  tooltip: isFullscreen
                                      ? 'Exit Full Screen'
                                      : 'Full Screen',
                                  onPressed: () => setState(
                                      () => isFullscreen = !isFullscreen),
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
                    child: LayoutBuilder(
                      builder: (context, previewConstraints) {
                        final preview = PdfPreview(
                          key: ValueKey(
                            '$thermal-$isFullscreen-${design.toJson()}',
                          ),
                          build: (_) => thermal
                              ? buildThermalReceiptPdf(company, transaction)
                              : buildInvoicePdf(
                                  company,
                                  transaction,
                                  settings: design,
                                ),
                          canChangePageFormat: false,
                          allowPrinting: true,
                          allowSharing: true,
                          canChangeOrientation: false,
                          canDebug: false,
                        );

                        if (!customize) return preview;

                        final panel = InvoiceCustomizationPanel(
                          settings: design,
                          onChanged: (value) => setState(() => design = value),
                          onReset: () => setState(() {
                            design = design.copyWith(
                              template: 'classic',
                              accentColor: 0xFF1E50D8,
                              showLogo: true,
                              showSellerDetails: true,
                              showAmountInWords: true,
                              showTaxSummary: true,
                              showDeclaration: true,
                              showBankDetails: true,
                              showSignature: true,
                              customTitle: '',
                              termsAndConditions: '',
                              footerText: '',
                            );
                          }),
                          onSave: () {
                            context.read<SettingsBloc>().add(
                                  SaveInvoiceSettingsRequested(design),
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Invoice design saved as default.',
                                ),
                              ),
                            );
                          },
                        );

                        if (previewConstraints.maxWidth >= 820) {
                          return Row(
                            children: [
                              SizedBox(width: 330, child: panel),
                              const VerticalDivider(width: 1),
                              Expanded(child: preview),
                            ],
                          );
                        }

                        final panelHeight = previewConstraints.maxHeight > 700
                            ? 340.0
                            : previewConstraints.maxHeight * 0.48;
                        return Column(
                          children: [
                            SizedBox(height: panelHeight, child: panel),
                            const Divider(height: 1),
                            Expanded(child: preview),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
