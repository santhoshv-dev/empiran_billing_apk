import 'package:empiran/app_store.dart';
import 'package:empiran/models.dart';
import 'package:empiran/invoice_pdf.dart';
import 'package:empiran/suite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore();
    await store.load();
    await store.addItem(
      Item(id: 'item', name: 'Product', salesPrice: 100, currentStock: 10),
    );
    await store.addParty(Party(id: 'party', name: 'Customer'));
  });
  List<InvoiceLine> lines() => [
        InvoiceLine(
          itemId: 'item',
          name: 'Product',
          quantity: 2,
          unit: 'Pcs',
          price: 100,
        ),
      ];

  test('reports escape CSV fields and generate PDF documents', () async {
    final t = await store.create(
      gst: true,
      type: 'order',
      lines: lines(),
      partyName: 'A, "B"\nCompany',
      dispatch: {'vehicleNo': 'TN01 AB1234'},
    );
    expect(reportCsv([t]), contains('"A, ""B""\nCompany"'));
    expect(t.dispatch['vehicleNo'], 'TN01 AB1234');
    final invoice = await buildInvoicePdf(store.company, t);
    final report = await buildReportPdf(store.company, [t], 'Sales Details');
    expect(String.fromCharCodes(invoice.take(4)), '%PDF');
    expect(String.fromCharCodes(report.take(4)), '%PDF');
  });

  test('backend transaction payloads map into Flutter domain models', () {
    final transaction = BusinessTransaction.fromJson({
      'id': '00000000-0000-0000-0000-000000000001',
      'txnType': 'sale_invoice',
      'txnNo': 'INV-1',
      'partyId': '00000000-0000-0000-0000-000000000002',
      'partyName': 'Cloud customer',
      'date': '2026-09-05T00:00:00Z',
      'lineItems': [
        {
          'itemId': null,
          'name': 'Service',
          'quantity': 1,
          'unit': 'Job',
          'price': 100,
        },
      ],
      'discountAmount': 10,
      'shippingCharges': 5,
      'cgst': 8.1,
      'sgst': 8.1,
      'paidAmount': 50,
      'paymentMode': 'upi',
      'status': 'partial',
      'referenceNo': 'quote-id',
      'notes': '{"text":"Cloud note","dispatch":{"vehicleNo":"TN01"}}',
    });
    expect(transaction.type, 'order');
    expect(transaction.total, closeTo(111.2, .001));
    expect(transaction.convertedFrom, 'quote-id');
    expect(transaction.notes, 'Cloud note');
    expect(transaction.dispatch['vehicleNo'], 'TN01');
  });

  test('quotation conversion, totals and stock survive reload', () async {
    final quote = await store.create(
      gst: false,
      type: 'quotation',
      lines: lines(),
    );
    expect(store.items.single.currentStock, 10);
    expect(store.settings.nonGstCounter, 1001);
    final order = await store.create(
      gst: true,
      type: 'order',
      lines: quote.lines,
      convertedFrom: quote.id,
      partyId: 'party',
      discount: 20,
      shipping: 10,
      paid: 100,
    );
    expect(order.total, closeTo(222.4, .001));
    expect(store.items.single.currentStock, 8);
    expect(store.partyBalance(store.parties.single), closeTo(122.4, .001));
    await expectLater(
      store.create(
        gst: false,
        type: 'order',
        lines: quote.lines,
        convertedFrom: quote.id,
      ),
      throwsStateError,
    );
    final reloaded = AppStore();
    await reloaded.load();
    expect(reloaded.transactions.first.convertedFrom, quote.id);
    expect(reloaded.transactions.first.total, closeTo(222.4, .001));
    await reloaded.deleteTransaction(reloaded.transactions.first);
    expect(reloaded.items.single.currentStock, 10);
  });

  test('purchases and returns move stock in the right direction', () async {
    for (final entry in [
      ('purchase_bill', 12.0),
      ('purchase_return', 10.0),
      ('sale_return', 12.0),
      ('sale_order', 12.0),
      ('purchase_order', 12.0),
    ]) {
      await store.create(gst: false, type: entry.$1, lines: lines());
      expect(store.items.single.currentStock, entry.$2);
    }
    store.items.single.isService = true;
    await store.create(gst: false, type: 'order', lines: lines());
    expect(store.items.single.currentStock, 12);
  });

  test('payments affect party ledger without changing inventory', () async {
    await store.create(
      gst: false,
      type: 'order',
      lines: lines(),
      partyId: 'party',
    );
    await store.create(
      gst: false,
      type: 'payment_in',
      lines: [
        InvoiceLine(
          itemId: '',
          name: 'Payment',
          quantity: 1,
          unit: '',
          price: 50,
        ),
      ],
      partyId: 'party',
    );
    expect(store.partyBalance(store.parties.single), 150);
    expect(store.items.single.currentStock, 8);
  });

  test('invalid amounts leave records and stock untouched', () async {
    await expectLater(
      store.create(gst: false, type: 'order', lines: lines(), discount: 201),
      throwsArgumentError,
    );
    await expectLater(
      store.create(gst: false, type: 'order', lines: lines(), paid: 201),
      throwsArgumentError,
    );
    await expectLater(
      store.create(gst: false, type: 'order', lines: []),
      throwsArgumentError,
    );
    expect(store.transactions, isEmpty);
    expect(store.items.single.currentStock, 10);
  });

  test('business switching isolates and persists all records', () async {
    final original = store.company.id;
    await store.addFirm('Second business');
    final second = store.company.id;
    expect(store.items, isEmpty);
    await store.addItem(Item(id: 'second', name: 'Second product'));
    await store.switchFirm(original);
    expect(store.items.single.id, 'item');
    final reloaded = AppStore();
    await reloaded.load();
    await reloaded.switchFirm(second);
    expect(reloaded.items.single.id, 'second');
  });

  testWidgets(
    'all navigation destinations render on mobile without exceptions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: SuiteShell(store: store, onLogout: () {}),
        ),
      );
      for (final label in [
        'Reports',
        'Settings & Users',
        'Dashboard',
        'POS Counter',
        'Payment In',
        'Sale Orders',
        'Sale Returns',
        'Purchase Bills',
        'Purchase Orders',
        'Payment Out',
        'Purchase Returns',
        'Expenses',
        'Cash & Bank',
        'WhatsApp Connect',
      ]) {
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        final target = find.widgetWithText(ListTile, label);
        await tester.scrollUntilVisible(
          target,
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    },
  );

  testWidgets('composer saves selected products with edited quantity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    BusinessTransaction? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await Navigator.push<BusinessTransaction>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceComposer(store, 'order'),
                  ),
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Product'));
    await tester.pumpAndSettle();
    final quantity = find.widgetWithText(TextFormField, 'Quantity (Pcs)');
    await tester.enterText(quantity, '3');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Total: ${money(300)}'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Total: ${money(300)}'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save & preview PDF'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Save & preview PDF'));
    await tester.pumpAndSettle();
    expect(saved?.total, 300);
    expect(store.transactions.single.lines.single.quantity, 3);
    expect(store.items.single.currentStock, 7);
    expect(tester.takeException(), isNull);
  });
}
