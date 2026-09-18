import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models.dart';

class InvoiceCustomizationPanel extends StatefulWidget {
  const InvoiceCustomizationPanel({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onReset,
    required this.onSave,
  });

  final InvoiceSettings settings;
  final ValueChanged<InvoiceSettings> onChanged;
  final VoidCallback onReset;
  final VoidCallback onSave;

  @override
  State<InvoiceCustomizationPanel> createState() =>
      _InvoiceCustomizationPanelState();
}

class _InvoiceCustomizationPanelState extends State<InvoiceCustomizationPanel> {
  late final TextEditingController _titleController;
  late final TextEditingController _termsController;
  late final TextEditingController _footerController;

  static const _colors = <int>[
    0xFF1E50D8,
    0xFF007F73,
    0xFFB42318,
    0xFF6B3FA0,
    0xFF374151,
    0xFFC2410C,
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.settings.customTitle);
    _termsController =
        TextEditingController(text: widget.settings.termsAndConditions);
    _footerController = TextEditingController(text: widget.settings.footerText);
  }

  @override
  void didUpdateWidget(covariant InvoiceCustomizationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_titleController, widget.settings.customTitle);
    _syncController(_termsController, widget.settings.termsAndConditions);
    _syncController(_footerController, widget.settings.footerText);
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _termsController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        children: [
          Row(
            children: [
              const Icon(Icons.palette_outlined,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Customize Invoice',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionLabel('Template'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'classic', label: Text('Classic')),
              ButtonSegment(value: 'modern', label: Text('Modern')),
              ButtonSegment(value: 'compact', label: Text('Compact')),
            ],
            selected: {settings.template},
            onSelectionChanged: (value) => widget.onChanged(
              settings.copyWith(template: value.first),
            ),
          ),
          const SizedBox(height: 18),
          const _SectionLabel('Accent Color'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final value in _colors)
                Tooltip(
                  message: _colorName(value),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => widget.onChanged(
                      settings.copyWith(accentColor: value),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: settings.accentColor == value
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: settings.accentColor == value
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const _SectionLabel('Visible Sections'),
          _toggle(
            'Business logo',
            settings.showLogo,
            (value) => settings.copyWith(showLogo: value),
          ),
          _toggle(
            'Seller details',
            settings.showSellerDetails,
            (value) => settings.copyWith(showSellerDetails: value),
          ),
          _toggle(
            'Amount in words',
            settings.showAmountInWords,
            (value) => settings.copyWith(showAmountInWords: value),
          ),
          _toggle(
            'GST summary',
            settings.showTaxSummary,
            (value) => settings.copyWith(showTaxSummary: value),
          ),
          _toggle(
            'Declaration',
            settings.showDeclaration,
            (value) => settings.copyWith(showDeclaration: value),
          ),
          _toggle(
            'Bank details',
            settings.showBankDetails,
            (value) => settings.copyWith(showBankDetails: value),
          ),
          _toggle(
            'Signature area',
            settings.showSignature,
            (value) => settings.copyWith(showSignature: value),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const _SectionLabel('Document Text'),
          const SizedBox(height: 10),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Custom heading',
              hintText: 'Use document type',
              prefixIcon: Icon(Icons.title_rounded),
            ),
            onChanged: (value) => widget.onChanged(
              settings.copyWith(customTitle: value),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _termsController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Terms & conditions',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.rule_outlined),
            ),
            onChanged: (value) => widget.onChanged(
              settings.copyWith(termsAndConditions: value),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _footerController,
            decoration: const InputDecoration(
              labelText: 'Footer note',
              prefixIcon: Icon(Icons.short_text_rounded),
            ),
            onChanged: (value) => widget.onChanged(
              settings.copyWith(footerText: value),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onReset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Default'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggle(
    String label,
    bool value,
    InvoiceSettings Function(bool value) update,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      onChanged: (next) => widget.onChanged(update(next)),
    );
  }

  static String _colorName(int value) => switch (value) {
        0xFF1E50D8 => 'Royal blue',
        0xFF007F73 => 'Teal',
        0xFFB42318 => 'Red',
        0xFF6B3FA0 => 'Purple',
        0xFF374151 => 'Charcoal',
        _ => 'Orange',
      };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}
