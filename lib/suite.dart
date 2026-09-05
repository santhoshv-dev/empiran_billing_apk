import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_store.dart';
import 'invoice_pdf.dart';
import 'models.dart';

const navItems = [
  ('Quotation Maker', Icons.request_quote_outlined),
  ('Orders & Invoices', Icons.receipt_long_outlined),
  ('Products & Inventory', Icons.inventory_2_outlined),
  ('Customers & Suppliers', Icons.groups_outlined),
  ('Reports', Icons.analytics_outlined),
  ('Settings & Users', Icons.settings_outlined),
];

class SuiteShell extends StatefulWidget {
  const SuiteShell({super.key, required this.store, required this.onLogout});
  final AppStore store;
  final VoidCallback onLogout;
  @override
  State<SuiteShell> createState() => _SuiteShellState();
}

class _SuiteShellState extends State<SuiteShell> {
  int page = 0;
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pages = [
      QuotePage(widget.store),
      OrdersPage(widget.store),
      ItemsPage(widget.store),
      PartiesPage(widget.store),
      ReportsPage(widget.store),
      SettingsPage(widget.store),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(navItems[page].$1),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                widget.store.company.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onLogout,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: wide ? null : Drawer(child: _navigation(context)),
      body: Row(
        children: [
          if (wide) SizedBox(width: 250, child: _navigation(context)),
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: pages[page]),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: (i) => setState(() => page = i),
              destinations: [
                for (final n in navItems.take(4))
                  NavigationDestination(
                    icon: Icon(n.$2),
                    label: n.$1.split(' ').first,
                  ),
              ],
            ),
    );
  }

  Widget _navigation(BuildContext context) => SafeArea(
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(22),
          child: Row(
            children: [
              CircleAvatar(child: Icon(Icons.account_balance)),
              SizedBox(width: 12),
              Text(
                'EMPIRAN',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: navItems.length,
            itemBuilder: (_, i) => ListTile(
              selected: i == page,
              leading: Icon(navItems[i].$2),
              title: Text(navItems[i].$1),
              onTap: () {
                setState(() => page = i);
                if (MediaQuery.sizeOf(context).width < 900)
                  Navigator.pop(context);
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });
  final String title, subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(subtitle),
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 20),
        Expanded(child: child),
      ],
    ),
  );
}

class QuotePage extends StatefulWidget {
  const QuotePage(this.store, {super.key});
  final AppStore store;
  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage> {
  final selected = <String, InvoiceLine>{};
  final name = TextEditingController(), phone = TextEditingController();
  void add(Item i) => setState(
    () => selected.update(
      i.id,
      (l) => InvoiceLine(
        itemId: l.itemId,
        name: l.name,
        quantity: l.quantity + 1,
        unit: l.unit,
        price: l.price,
        hsn: l.hsn,
      ),
      ifAbsent: () => InvoiceLine(
        itemId: i.id,
        name: i.name,
        quantity: 1,
        unit: i.unit,
        price: i.salesPrice,
        hsn: i.hsn,
      ),
    ),
  );
  Future<void> generate() async {
    if (selected.isEmpty) return;
    final q = await widget.store.create(
      gst: false,
      type: 'quotation',
      lines: selected.values.toList(),
      partyName: name.text,
      partyPhone: phone.text,
      deductStock: false,
    );
    if (mounted) {
      selected.clear();
      setState(() {});
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Quotation generated'),
          content: Text(
            'Quotation ${q.number} was saved. Stock was not affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _convert(q);
              },
              child: const Text('Convert to order'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _convert(BusinessTransaction q) async {
    final gst = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Convert quotation'),
        content: const Text('Saving the order will deduct stock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non-GST order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('GST order'),
          ),
        ],
      ),
    );
    if (gst == null) return;
    await widget.store.create(
      gst: gst,
      type: 'order',
      lines: q.lines,
      partyName: q.partyName,
      partyPhone: q.partyPhone,
    );
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Quotation Maker',
    subtitle:
        'Create estimates without changing stock, then convert in one click.',
    child: LayoutBuilder(
      builder: (_, c) {
        final products = GridView.builder(
          itemCount: widget.store.items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: c.maxWidth > 900
                ? 3
                : c.maxWidth > 560
                ? 2
                : 1,
            mainAxisExtent: 125,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (_, x) {
            final i = widget.store.items[x];
            return Card(
              child: InkWell(
                onTap: () => add(i),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _ProductImage(i.image),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              i.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('INR ${i.salesPrice.toStringAsFixed(2)}'),
                            Text(
                              'Stock ${i.currentStock} ${i.unit}',
                              style: TextStyle(
                                color: i.currentStock <= i.lowStockLimit
                                    ? Colors.orange
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.add_circle_outline),
                    ],
                  ),
                ),
              ),
            );
          },
        );
        final cart = Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Customer name (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                ),
                const Divider(height: 28),
                Expanded(
                  child: selected.isEmpty
                      ? const Center(
                          child: Text('Select products to build a quotation'),
                        )
                      : ListView(
                          children: selected.values
                              .map(
                                (l) => ListTile(
                                  title: Text(l.name),
                                  subtitle: Text(
                                    '${l.quantity} × INR ${l.price}',
                                  ),
                                  trailing: Text(
                                    'INR ${l.total.toStringAsFixed(2)}',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const Divider(),
                Row(
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      'INR ${selected.values.fold<double>(0, (a, b) => a + b.total).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: selected.isEmpty ? null : generate,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Generate quotation (stock safe)'),
                  ),
                ),
              ],
            ),
          ),
        );
        return c.maxWidth > 760
            ? Row(
                children: [
                  Expanded(flex: 3, child: products),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: cart),
                ],
              )
            : Column(
                children: [
                  Expanded(child: products),
                  const SizedBox(height: 12),
                  SizedBox(height: 330, child: cart),
                ],
              );
      },
    ),
  );
}

class OrdersPage extends StatelessWidget {
  const OrdersPage(this.store, {super.key});
  final AppStore store;
  Future<void> preview(BuildContext c, BusinessTransaction t) async =>
      showDialog(
        context: c,
        builder: (_) => Dialog(
          child: SizedBox(
            width: 900,
            height: 700,
            child: PdfPreview(
              build: (_) => buildInvoicePdf(store.company, t),
              canChangePageFormat: false,
            ),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final orders = store.transactions.where((x) => x.type == 'order').toList();
    return PageFrame(
      title: 'Orders & Invoices',
      subtitle:
          'GST invoices include 9% CGST + 9% SGST; stock is deducted on save.',
      action: FilledButton.icon(
        onPressed: store.items.isEmpty
            ? null
            : () async {
                final gst = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Quick order'),
                    content: Text(
                      'Create an order using 1 × ${store.items.first.name}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Non-GST'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('GST'),
                      ),
                    ],
                  ),
                );
                if (gst != null)
                  await store.create(
                    gst: gst,
                    type: 'order',
                    lines: [
                      InvoiceLine(
                        itemId: store.items.first.id,
                        name: store.items.first.name,
                        quantity: 1,
                        unit: store.items.first.unit,
                        price: store.items.first.salesPrice,
                      ),
                    ],
                  );
              },
        icon: const Icon(Icons.add),
        label: const Text('New order'),
      ),
      child: orders.isEmpty
          ? const Center(
              child: Text(
                'No orders yet. Convert a quotation or create a quick order.',
              ),
            )
          : ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = orders[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        t.isGst ? Icons.receipt : Icons.shopping_bag_outlined,
                      ),
                    ),
                    title: Text(
                      '# ${t.number} • ${t.partyName.isEmpty ? 'Cash Customer' : t.partyName}',
                    ),
                    subtitle: Text(
                      '${DateFormat.yMMMd().format(t.date)} • ${t.isGst ? 'GST' : 'Non-GST'} • ${t.status}',
                    ),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'INR ${t.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => preview(context, t),
                          tooltip: 'Preview / Print PDF',
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage(this.data);
  final String? data;
  @override
  Widget build(BuildContext context) {
    if (data != null) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(data!.contains(',') ? data!.split(',').last : data!),
            width: 62,
            height: 62,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.inventory_2_outlined),
    );
  }
}

class ItemsPage extends StatelessWidget {
  const ItemsPage(this.store, {super.key});
  final AppStore store;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Products & Inventory',
    subtitle: 'Prices, product images, stock levels and low-stock warnings.',
    action: FilledButton.icon(
      onPressed: () => _itemDialog(context, store),
      icon: const Icon(Icons.add),
      label: const Text('Add product'),
    ),
    child: store.items.isEmpty
        ? const Center(
            child: Text('No products. Add the first product to start billing.'),
          )
        : GridView.builder(
            itemCount: store.items.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380,
              mainAxisExtent: 125,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (_, i) {
              final x = store.items[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _ProductImage(x.image),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              x.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text('${x.itemCode} • ${x.category}'),
                            Text('INR ${x.salesPrice.toStringAsFixed(2)}'),
                            Text(
                              '${x.currentStock} ${x.unit} in stock',
                              style: TextStyle(
                                color: x.currentStock <= x.lowStockLimit
                                    ? Colors.orange
                                    : null,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

Future<void> _itemDialog(BuildContext context, AppStore store) async {
  final name = TextEditingController(),
      code = TextEditingController(),
      price = TextEditingController(),
      stock = TextEditingController(),
      hsn = TextEditingController();
  String? image;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Add product'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Product name *',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'Item code'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sales price *',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Opening stock',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hsn,
                  decoration: const InputDecoration(labelText: 'HSN'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final f = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                      maxWidth: 1000,
                    );
                    if (f != null) {
                      image = base64Encode(await f.readAsBytes());
                      set(() {});
                    }
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    image == null ? 'Choose product image' : 'Image selected',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await store.addItem(
                Item(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: name.text.trim(),
                  itemCode: code.text.trim(),
                  hsn: hsn.text.trim(),
                  salesPrice: double.tryParse(price.text) ?? 0,
                  currentStock: double.tryParse(stock.text) ?? 0,
                  image: image,
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class PartiesPage extends StatelessWidget {
  const PartiesPage(this.store, {super.key});
  final AppStore store;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Customers & Suppliers',
    subtitle: 'Party contacts, GST details, balances and transaction ledger.',
    action: FilledButton.icon(
      onPressed: () => _partyDialog(context, store),
      icon: const Icon(Icons.person_add_alt),
      label: const Text('Add party'),
    ),
    child: store.parties.isEmpty
        ? const Center(
            child: Text(
              'No parties yet. Customer details remain optional during billing.',
            ),
          )
        : ListView.separated(
            itemCount: store.parties.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = store.parties[i];
              final tx = store.transactions
                  .where((t) => t.partyName == p.name)
                  .length;
              return Card(
                child: ExpansionTile(
                  leading: CircleAvatar(child: Text(p.name[0].toUpperCase())),
                  title: Text(p.name),
                  subtitle: Text(
                    '${p.type} • ${p.phone}${p.gstin.isEmpty ? '' : ' • GST ${p.gstin}'}',
                  ),
                  trailing: Text('INR ${p.balance.toStringAsFixed(2)}'),
                  children: [
                    ListTile(
                      title: Text(
                        p.address.isEmpty ? 'No address recorded' : p.address,
                      ),
                      subtitle: Text('$tx ledger transactions • ${p.email}'),
                    ),
                  ],
                ),
              );
            },
          ),
  );
}

Future<void> _partyDialog(BuildContext context, AppStore store) async {
  final n = TextEditingController(),
      ph = TextEditingController(),
      em = TextEditingController(),
      gst = TextEditingController(),
      address = TextEditingController();
  String type = 'Customer';
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Add customer / supplier'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: n,
                  decoration: const InputDecoration(labelText: 'Name *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ph,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: em,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField(
                  value: type,
                  items: ['Customer', 'Supplier', 'Both']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (v) => set(() => type = v!),
                  decoration: const InputDecoration(labelText: 'Party type'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: gst,
                  decoration: const InputDecoration(labelText: 'GSTIN / UIN'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: address,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (n.text.trim().isEmpty) return;
              await store.addParty(
                Party(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: n.text.trim(),
                  phone: ph.text,
                  email: em.text,
                  type: type,
                  gstin: gst.text,
                  address: address.text,
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

enum ReportRange { today, month, last30, all }

class ReportsPage extends StatefulWidget {
  const ReportsPage(this.store, {super.key});
  final AppStore store;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int tab = 0;
  ReportRange range = ReportRange.all;
  DateTime? from, to;
  List<BusinessTransaction> get rows {
    var data = widget.store.transactions
        .where(
          (t) => tab == 0
              ? true
              : tab == 1
              ? t.type == 'order'
              : t.paid > 0,
        )
        .toList();
    final now = DateTime.now();
    DateTime? start, end;
    if (range == ReportRange.today) {
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
    } else if (range == ReportRange.month) {
      start = DateTime(now.year, now.month);
      end = DateTime(now.year, now.month + 1);
    } else if (range == ReportRange.last30) {
      start = now.subtract(const Duration(days: 30));
      end = now.add(const Duration(days: 1));
    } else {
      start = from;
      end = to?.add(const Duration(days: 1));
    }
    return data
        .where(
          (t) =>
              (start == null || !t.date.isBefore(start)) &&
              (end == null || t.date.isBefore(end)),
        )
        .toList();
  }

  String summary() {
    final r = rows,
        total = r.fold<double>(0, (a, b) => a + b.total),
        paid = r.fold<double>(0, (a, b) => a + b.paid);
    return '${['Transaction Details', 'Sales Details', 'Payment Details'][tab]}\nRecords: ${r.length}\nTotal: INR ${total.toStringAsFixed(2)}\nPaid: INR ${paid.toStringAsFixed(2)}\nOutstanding: INR ${(total - paid).toStringAsFixed(2)}';
  }

  Future<void> shareWhatsApp() async {
    await launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(summary())}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> csv() async {
    final content =
        'Number,Date,Party,Type,Total,Paid,Balance\n${rows.map((t) => '${t.number},${DateFormat('yyyy-MM-dd').format(t.date)},"${t.partyName}",${t.type},${t.total},${t.paid},${t.balance}').join('\n')}';
    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(text: content, subject: 'Empiran report.csv'),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}empiran_report.csv');
    await f.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)], subject: 'Empiran report'),
    );
  }

  Future<void> printReport() async {
    final fake = BusinessTransaction(
      id: 'report',
      type: 'report',
      number: 'REPORT',
      date: DateTime.now(),
      lines: rows
          .map(
            (t) => InvoiceLine(
              itemId: t.id,
              name: '${t.number} ${t.partyName}',
              quantity: 1,
              unit: 'Txn',
              price: t.total,
            ),
          )
          .toList(),
    );
    await Printing.layoutPdf(
      onLayout: (_) => buildInvoicePdf(widget.store.company, fake),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = rows,
        total = r.fold<double>(0, (a, b) => a + b.total),
        paid = r.fold<double>(0, (a, b) => a + b.paid);
    return PageFrame(
      title: 'Reports',
      subtitle: 'Focused transaction, sales and payment reporting.',
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < 3; i)
                ChoiceChip(
                  label: Text(
                    [
                      'Transaction Details',
                      'Sales Details',
                      'Payment Details',
                    ][i],
                  ),
                  selected: tab == i,
                  onSelected: (_) => setState(() => tab = i),
                ),
              for (final x in ReportRange.values)
                ChoiceChip(
                  label: Text(
                    {
                      ReportRange.today: 'Today',
                      ReportRange.month: 'This Month',
                      ReportRange.last30: 'Last 30 Days',
                      ReportRange.all: 'All Time',
                    }[x]!,
                  ),
                  selected: range == x,
                  onSelected: (_) => setState(() => range = x),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric('Records', '${r.length}', Icons.list_alt),
              _Metric(
                'Total',
                'INR ${total.toStringAsFixed(2)}',
                Icons.currency_rupee,
              ),
              _Metric(
                'Paid',
                'INR ${paid.toStringAsFixed(2)}',
                Icons.payments_outlined,
              ),
              _Metric(
                'Outstanding',
                'INR ${(total - paid).toStringAsFixed(2)}',
                Icons.pending_actions,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: shareWhatsApp,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Share WhatsApp'),
              ),
              OutlinedButton.icon(
                onPressed: csv,
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Export CSV'),
              ),
              FilledButton.icon(
                onPressed: printReport,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print Report'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: r.isEmpty
                ? const Center(child: Text('No records in this period.'))
                : ListView.builder(
                    itemCount: r.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text('# ${r[i].number} • ${r[i].partyName}'),
                      subtitle: Text(DateFormat.yMMMd().format(r[i].date)),
                      trailing: Text('INR ${r[i].total.toStringAsFixed(2)}'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage(this.store, {super.key});
  final AppStore store;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 3, vsync: this);
  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Settings & Users',
    subtitle: 'Business identity, staff access and invoice numbering.',
    child: Column(
      children: [
        TabBar(
          controller: tabs,
          tabs: const [
            Tab(text: 'Company Profile', icon: Icon(Icons.business_outlined)),
            Tab(
              text: 'Users & Staff',
              icon: Icon(Icons.manage_accounts_outlined),
            ),
            Tab(text: 'Invoice Control', icon: Icon(Icons.pin_outlined)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: tabs,
            children: [
              _CompanyForm(widget.store),
              _Users(widget.store),
              _InvoiceControl(widget.store),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CompanyForm extends StatefulWidget {
  const _CompanyForm(this.store);
  final AppStore store;
  @override
  State<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<_CompanyForm> {
  late final fields = <String, TextEditingController>{
    for (final e in {
      'name': widget.store.company.name,
      'gstin': widget.store.company.gstin,
      'address': widget.store.company.address,
      'phone': widget.store.company.phone,
      'state': widget.store.company.state,
      'stateCode': widget.store.company.stateCode,
      'email': widget.store.company.email,
      'bankName': widget.store.company.bankName,
      'accountNo': widget.store.company.accountNo,
      'branch': widget.store.company.branch,
      'ifsc': widget.store.company.ifsc,
    }.entries)
      e.key: TextEditingController(text: e.value),
  };
  String? logo;
  @override
  void initState() {
    super.initState();
    logo = widget.store.company.logo;
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final x in [
                  ('name', 'Company Name *'),
                  ('gstin', 'GSTIN / UIN *'),
                  ('phone', 'Mobile / Contact *'),
                  ('state', 'State Name'),
                  ('stateCode', 'State Code'),
                  ('email', 'Email'),
                  ('bankName', 'Bank Name'),
                  ('accountNo', 'Account No'),
                  ('branch', 'Branch'),
                  ('ifsc', 'IFSC'),
                ])
                  SizedBox(
                    width: 330,
                    child: TextField(
                      controller: fields[x.$1],
                      decoration: InputDecoration(labelText: x.$2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fields['address'],
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Full Address *'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final f = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 75,
                      maxWidth: 1200,
                    );
                    if (f != null) {
                      final bytes = await f.readAsBytes();
                      setState(() => logo = base64Encode(bytes));
                    }
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    logo == null ? 'Upload company logo' : 'Change logo',
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    if ([
                      'name',
                      'gstin',
                      'address',
                      'phone',
                    ].any((k) => fields[k]!.text.trim().isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Complete all mandatory fields.'),
                        ),
                      );
                      return;
                    }
                    final c = widget.store.company;
                    c.name = fields['name']!.text;
                    c.gstin = fields['gstin']!.text;
                    c.address = fields['address']!.text;
                    c.phone = fields['phone']!.text;
                    c.state = fields['state']!.text;
                    c.stateCode = fields['stateCode']!.text;
                    c.email = fields['email']!.text;
                    c.bankName = fields['bankName']!.text;
                    c.accountNo = fields['accountNo']!.text;
                    c.branch = fields['branch']!.text;
                    c.ifsc = fields['ifsc']!.text;
                    c.logo = logo;
                    await widget.store.saveCompany();
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Company profile saved.')),
                      );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Users extends StatelessWidget {
  const _Users(this.store);
  final AppStore store;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () => _userDialog(context, store),
          icon: const Icon(Icons.person_add),
          label: const Text('Create staff account'),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: ListView.builder(
          itemCount: store.users.length,
          itemBuilder: (_, i) {
            final u = store.users[i];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(u['name']!),
                subtitle: Text('${u['username']} • ${u['email']}'),
                trailing: Chip(label: Text(u['role']!)),
              ),
            );
          },
        ),
      ),
    ],
  );
}

Future<void> _userDialog(BuildContext context, AppStore store) async {
  final n = TextEditingController(),
      u = TextEditingController(),
      e = TextEditingController(),
      p = TextEditingController();
  String role = 'Billing Staff';
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Create staff account'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: n,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: u,
                decoration: const InputDecoration(labelText: 'Username *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: e,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: p,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password *'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField(
                value: role,
                items: ['Billing Staff', 'Manager', 'Admin']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (v) => set(() => role = v!),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (n.text.isEmpty || u.text.isEmpty || p.text.isEmpty) return;
              await store.addUser({
                'name': n.text,
                'username': u.text,
                'email': e.text,
                'role': role,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}

class _InvoiceControl extends StatefulWidget {
  const _InvoiceControl(this.store);
  final AppStore store;
  @override
  State<_InvoiceControl> createState() => _InvoiceControlState();
}

class _InvoiceControlState extends State<_InvoiceControl> {
  late final gy = TextEditingController(text: widget.store.settings.gstYear),
      gc = TextEditingController(text: '${widget.store.settings.gstCounter}'),
      np = TextEditingController(text: widget.store.settings.nonGstPrefix),
      nc = TextEditingController(
        text: '${widget.store.settings.nonGstCounter}',
      );
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'GST Order Sequence',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: gy,
                    decoration: const InputDecoration(
                      labelText: 'Financial year tag',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: gc,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Current counter',
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Preview: # ${gc.text}/${gy.text}'),
            ),
            const Divider(height: 36),
            Text(
              'Non-GST Order Sequence',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: np,
                    decoration: const InputDecoration(labelText: 'Prefix'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: nc,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Starting counter',
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Preview: # ${np.text}${nc.text}'),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  widget.store.settings.gstYear = gy.text;
                  widget.store.settings.gstCounter = int.tryParse(gc.text) ?? 1;
                  widget.store.settings.nonGstPrefix = np.text;
                  widget.store.settings.nonGstCounter =
                      int.tryParse(nc.text) ?? 1001;
                  await widget.store.saveSettings();
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save sequences'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
