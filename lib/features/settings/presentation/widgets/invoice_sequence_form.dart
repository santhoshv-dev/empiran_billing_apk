import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../../../../models.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';

class InvoiceSequenceForm extends StatefulWidget {
  final InvoiceSettings settings;

  const InvoiceSequenceForm({super.key, required this.settings});

  @override
  State<InvoiceSequenceForm> createState() => _InvoiceSequenceFormState();
}

class _InvoiceSequenceFormState extends State<InvoiceSequenceForm>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final TextEditingController _gstYear;
  late final TextEditingController _gstCounter;
  late final TextEditingController _nonGstPrefix;
  late final TextEditingController _nonGstCounter;

  @override
  void initState() {
    super.initState();
    _gstYear = TextEditingController(text: widget.settings.gstYear);
    _gstCounter = TextEditingController(text: '${widget.settings.gstCounter}');
    _nonGstPrefix = TextEditingController(text: widget.settings.nonGstPrefix);
    _nonGstCounter = TextEditingController(text: '${widget.settings.nonGstCounter}');
  }

  @override
  void dispose() {
    _gstYear.dispose();
    _gstCounter.dispose();
    _nonGstPrefix.dispose();
    _nonGstCounter.dispose();
    super.dispose();
  }

  void _save() {
    final updated = InvoiceSettings(
      gstYear: _gstYear.text.trim(),
      gstCounter: int.tryParse(_gstCounter.text) ?? 1,
      nonGstPrefix: _nonGstPrefix.text.trim(),
      nonGstCounter: int.tryParse(_nonGstCounter.text) ?? 1001,
    );

    context.read<SettingsBloc>().add(SaveInvoiceSettingsRequested(updated));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Numbering sequences updated successfully.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SingleChildScrollView(
      child: EmpiranCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'GST Invoice Sequence',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Standard fiscal year numbering format used for tax invoices.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 480;
                final yearField = EmpiranTextField(
                  controller: _gstYear,
                  label: 'Financial Year Tag',
                  hint: 'e.g. 25-26',
                );
                final counterField = EmpiranTextField(
                  controller: _gstCounter,
                  label: 'Starting Counter',
                  hint: '1',
                  isNumber: true,
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      yearField,
                      const SizedBox(height: 12),
                      counterField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: yearField),
                    const SizedBox(width: 14),
                    Expanded(child: counterField),
                  ],
                );
              },
            ),
            const Divider(height: 40),
            const Text(
              'Non-GST / Cash Bill Sequence',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sequential numbering for estimates, cash memos and standard receipts.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 480;
                final prefixField = EmpiranTextField(
                  controller: _nonGstPrefix,
                  label: 'Prefix Tag',
                  hint: 'e.g. ORD-',
                );
                final nonGstCounterField = EmpiranTextField(
                  controller: _nonGstCounter,
                  label: 'Starting Counter',
                  hint: '1001',
                  isNumber: true,
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      prefixField,
                      const SizedBox(height: 12),
                      nonGstCounterField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: prefixField),
                    const SizedBox(width: 14),
                    Expanded(child: nonGstCounterField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: Listenable.merge([_nonGstPrefix, _nonGstCounter]),
              builder: (_, __) => Text(
                'Preview: #${_nonGstPrefix.text}${_nonGstCounter.text}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: EmpiranButton(
                label: 'Save Sequences',
                icon: Icons.save_outlined,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
