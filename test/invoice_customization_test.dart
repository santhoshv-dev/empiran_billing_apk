import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:empiran/features/invoices/presentation/widgets/invoice_customization_panel.dart';
import 'package:empiran/models.dart';

void main() {
  test('legacy invoice settings receive design defaults', () {
    final settings = InvoiceSettings.fromJson({
      'gstYear': '26-27',
      'gstCounter': 8,
      'nonGstPrefix': 'BILL-',
      'nonGstCounter': 42,
    });

    expect(settings.template, 'classic');
    expect(settings.accentColor, 0xFF1E50D8);
    expect(settings.showBankDetails, isTrue);
    expect(settings.customTitle, isEmpty);
  });

  test('invoice design settings survive serialization', () {
    final original = InvoiceSettings(
      template: 'modern',
      accentColor: 0xFF007F73,
      showLogo: false,
      showTaxSummary: false,
      showDeclaration: false,
      customTitle: 'Sales Invoice',
      termsAndConditions: 'Payment due within 15 days.',
      footerText: 'Thank you for your business.',
    );

    final restored = InvoiceSettings.fromJson(original.toJson());

    expect(restored.template, 'modern');
    expect(restored.accentColor, 0xFF007F73);
    expect(restored.showLogo, isFalse);
    expect(restored.showTaxSummary, isFalse);
    expect(restored.showDeclaration, isFalse);
    expect(restored.customTitle, 'Sales Invoice');
    expect(restored.termsAndConditions, 'Payment due within 15 days.');
    expect(restored.footerText, 'Thank you for your business.');
  });

  testWidgets('customization panel updates the selected template',
      (tester) async {
    var settings = InvoiceSettings();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: InvoiceCustomizationPanel(
              settings: settings,
              onChanged: (value) => settings = value,
              onReset: () {},
              onSave: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Modern'));
    await tester.pump();

    expect(settings.template, 'modern');
    expect(find.text('Customize Invoice'), findsOneWidget);
    expect(find.text('Business logo'), findsOneWidget);
  });
}
