import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_store.dart';
import 'invoice_pdf.dart';
import 'models.dart';

part 'workflows.dart';

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
      QuotationWorkspace(widget.store),
      TransactionPage(widget.store, 'order', key: const ValueKey('order')),
      CatalogPage(widget.store),
      CatalogPage(widget.store, parties: true),
      ReportsPage(widget.store),
      SettingsPage(widget.store),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(navItems[page].$1, overflow: TextOverflow.ellipsis),
        actions: [
          FilledButton.icon(
            onPressed: () => openComposer(context, widget.store, 'order'),
            icon: const Icon(Icons.add),
            label: wide ? const Text('Sale Invoice') : const SizedBox.shrink(),
          ),
          if (wide)
            TextButton.icon(
              onPressed: () => openComposer(context, widget.store, 'payment_in'),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Payment In'),
            ),
          IconButton(
            tooltip: 'Switch business',
            onPressed: () => switchBusiness(context, widget.store),
            icon: const Icon(Icons.business),
          ),
          IconButton(
            tooltip: 'Search anything',
            onPressed: () => showSearch(
              context: context,
              delegate: BusinessSearch(widget.store),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Toggle dark mode',
            onPressed: widget.store.toggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          if (wide)
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
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(widget.store.company.id),
              child: pages[page],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page < 4 ? page : 4,
              onDestinationSelected: (i) {
                if (i < 4) {
                  setState(() => page = i);
                } else {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => ListView(
                      children: [
                        for (var n = 4; n < navItems.length; n++)
                          ListTile(
                            leading: Icon(navItems[n].$2),
                            title: Text(navItems[n].$1),
                            onTap: () {
                              setState(() => page = n);
                              Navigator.pop(context);
                            },
                          ),
                      ],
                    ),
                  );
                }
              },
              destinations: [
                for (final n in navItems.take(4))
                  NavigationDestination(
                    icon: Icon(n.$2),
                    label: n.$1.split(' ').first,
                  ),
                const NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            ),
    );
  }

  Widget _navigation(BuildContext context) => ColoredBox(
    color: const Color(0xff020617),
    child: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(22),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xff0f172a),
                  backgroundImage: AssetImage(
                    'assets/images/empiran_traders_logo.png',
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'EMPIRAN',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              itemBuilder: (_, i) => ListTile(
                selected: i == page,
                selectedColor: Colors.white,
                selectedTileColor: const Color(0xff2563eb),
                textColor: const Color(0xffcbd5e1),
                iconColor: const Color(0xff60a5fa),
                leading: Icon(navItems[i].$2),
                title: Text(navItems[i].$1),
                onTap: () {
                  setState(() => page = i);
                  if (MediaQuery.sizeOf(context).width < 900) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
        ],
      ),
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
            ?action,
          ],
        ),
        const SizedBox(height: 20),
        Expanded(child: child),
      ],
    ),
  );
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

Future<void> _itemDialog(
  BuildContext context,
  AppStore store, {
  Item? item,
}) async {
  final name = TextEditingController(),
      code = TextEditingController(),
      price = TextEditingController(),
      stock = TextEditingController(),
      hsn = TextEditingController();
  final purchase = TextEditingController(text: '${item?.purchasePrice ?? 0}'),
      category = TextEditingController(text: item?.category ?? 'General'),
      unit = TextEditingController(text: item?.unit ?? 'Pcs'),
      low = TextEditingController(text: '${item?.lowStockLimit ?? 5}');
  name.text = item?.name ?? '';
  code.text = item?.itemCode ?? '';
  price.text = '${item?.salesPrice ?? 0}';
  stock.text = '${item?.currentStock ?? 0}';
  hsn.text = item?.hsn ?? '';
  bool service = item?.isService ?? false;
  String? image = item?.image;
  String? error;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(item == null ? 'Add product' : 'Edit product'),
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
                for (final field in [
                  ('Purchase price', purchase),
                  ('Category', category),
                  ('Unit', unit),
                  ('Low stock limit', low),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: field.$2,
                      decoration: InputDecoration(labelText: field.$1),
                    ),
                  ),
                SwitchListTile(
                  title: const Text('Service (no stock movement)'),
                  value: service,
                  onChanged: (v) => set(() => service = v),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
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
              if (name.text.trim().isEmpty ||
                  [price, purchase, stock, low].any(
                    (c) =>
                        double.tryParse(c.text) == null ||
                        !double.parse(c.text).isFinite,
                  ) ||
                  double.parse(price.text) < 0 ||
                  double.parse(purchase.text) < 0 ||
                  double.parse(low.text) < 0) {
                set(
                  () =>
                      error = 'Enter a name and valid prices, stock and limit.',
                );
                return;
              }
              try {
                await store.addItem(
                  Item(
                    id:
                        item?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    purchasePrice: double.parse(purchase.text),
                    category: category.text,
                    unit: unit.text,
                    lowStockLimit: double.parse(low.text),
                    isService: service,
                    name: name.text.trim(),
                    itemCode: code.text.trim(),
                    hsn: hsn.text.trim(),
                    salesPrice: double.tryParse(price.text) ?? 0,
                    currentStock: double.tryParse(stock.text) ?? 0,
                    image: image,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                set(() => error = '$e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  for (final c in [
    name,
    code,
    price,
    stock,
    hsn,
    purchase,
    category,
    unit,
    low,
  ]) {
    c.dispose();
  }
}

Future<void> _partyDialog(
  BuildContext context,
  AppStore store, {
  Party? party,
}) async {
  final n = TextEditingController(),
      ph = TextEditingController(),
      em = TextEditingController(),
      gst = TextEditingController(),
      address = TextEditingController();
  n.text = party?.name ?? '';
  ph.text = party?.phone ?? '';
  em.text = party?.email ?? '';
  gst.text = party?.gstin ?? '';
  address.text = party?.address ?? '';
  final balance = TextEditingController(text: '${party?.balance ?? 0}');
  String? error;
  String type = party?.type ?? 'Customer';
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(
          party == null
              ? 'Add customer / supplier'
              : 'Edit customer / supplier',
        ),
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
                  initialValue: type,
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
                  controller: balance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Opening balance (+ receivable / - payable)',
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
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
              if (n.text.trim().isEmpty ||
                  double.tryParse(balance.text) == null ||
                  !double.parse(balance.text).isFinite) {
                set(() => error = 'Enter a name and valid opening balance.');
                return;
              }
              try {
                await store.addParty(
                  Party(
                    id:
                        party?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    balance: double.parse(balance.text),
                    name: n.text.trim(),
                    phone: ph.text,
                    email: em.text,
                    type: type,
                    gstin: gst.text,
                    address: address.text,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                set(() => error = '$e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  for (final c in [n, ph, em, gst, address, balance]) {
    c.dispose();
  }
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
              ? [
                  'order',
                  'sale_invoice',
                  'sale_order',
                  'quotation',
                  'estimate',
                ].contains(t.type)
              : t.paid > 0 || t.type.startsWith('payment_'),
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
    final content = reportCsv(rows);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(content)),
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: ['empiran-report.csv'],
      ),
    );
  }

  Future<void> printReport() async {
    await Printing.layoutPdf(
      onLayout: (_) => buildReportPdf(
        widget.store.company,
        rows,
        ['Transaction Details', 'Sales Details', 'Payment Details'][tab],
      ),
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
      child: ListView(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < 3; i++)
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
              TextButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                  from == null
                      ? 'Custom dates'
                      : '${DateFormat.yMd().format(from!)} ? ${DateFormat.yMd().format(to!)}',
                ),
                onPressed: () async {
                  final dates = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (dates != null && mounted) {
                    setState(() {
                      from = dates.start;
                      to = dates.end;
                      range = ReportRange.all;
                    });
                  }
                },
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
                  onSelected: (_) => setState(() {
                    range = x;
                    from = null;
                    to = null;
                  }),
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
          SizedBox(
            height: 420,
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
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

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
            Wrap(
              spacing: 12,
              runSpacing: 12,
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
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Company profile saved.')),
                      );
                    }
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
                trailing: PopupMenuButton<String>(
                  tooltip: 'Manage staff',
                  onSelected: (value) async {
                    if (value == 'delete' &&
                        await confirmDelete(
                          context,
                          'Delete this staff account?',
                        )) {
                      store.users.remove(u);
                      await store.persist();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(enabled: false, child: Text(u['role']!)),
                    if (u['username'] != 'empirantraders')
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete account'),
                      ),
                  ],
                ),
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
  String? error;
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
                initialValue: role,
                items: ['Billing Staff', 'Manager', 'Admin']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (v) => set(() => role = v!),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
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
              if (n.text.trim().isEmpty ||
                  u.text.trim().isEmpty ||
                  p.text.trim().isEmpty) {
                set(() => error = 'Name, username and password are required.');
                return;
              }
              if (store.users.any(
                (x) =>
                    x['username']?.toLowerCase() ==
                        u.text.trim().toLowerCase() ||
                    (e.text.trim().isNotEmpty &&
                        x['email']?.toLowerCase() ==
                            e.text.trim().toLowerCase()),
              )) {
                set(() => error = 'Username or email already exists.');
                return;
              }
              await store.addUser({
                'name': n.text,
                'username': u.text.trim(),
                'email': e.text.trim(),
                'role': role,
                'password': p.text,
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
