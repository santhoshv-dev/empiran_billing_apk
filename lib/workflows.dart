part of 'suite.dart';

class QuotationWorkspace extends StatelessWidget {
  const QuotationWorkspace(this.store, {super.key});
  final AppStore store;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'Quotation Maker'),
            Tab(text: 'Saved Quotations'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              InvoiceComposer(store, 'quotation', embedded: true),
              TransactionPage(store, 'quotation'),
            ],
          ),
        ),
      ],
    ),
  );
}

class WhatsAppPage extends StatefulWidget {
  const WhatsAppPage({super.key});
  @override
  State<WhatsAppPage> createState() => _WhatsAppPageState();
}

class _WhatsAppPageState extends State<WhatsAppPage> {
  final phone = TextEditingController(), message = TextEditingController();
  @override
  void dispose() {
    phone.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'WhatsApp Connect',
    subtitle:
        'Open a message draft or share a document from transaction history.',
    child: ListView(
      children: [
        const Icon(Icons.chat, size: 80, color: Colors.green),
        const SizedBox(height: 20),
        const Text(
          'Send invoices and payment details',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: phone,
          decoration: const InputDecoration(
            labelText: 'Phone with country code',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: message,
          decoration: const InputDecoration(labelText: 'Message'),
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final uri = Uri.https(
              'wa.me',
              '/${phone.text.replaceAll(RegExp(r'[^0-9]'), '')}',
              {'text': message.text},
            );
            final opened = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unable to open WhatsApp.')),
              );
            }
          },
          child: const Text('Open WhatsApp draft'),
        ),
        const SizedBox(height: 20),
        const Text(
          'For PDF attachments, use PDF / Print / Share on a saved transaction and choose WhatsApp. You review and send the message in WhatsApp.',
        ),
      ],
    ),
  );
}

class BusinessSearch extends SearchDelegate<void> {
  BusinessSearch(this.store);
  final AppStore store;
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );
  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);
  @override
  Widget buildSuggestions(BuildContext context) => ListView(
    children: [
      for (final i in store.items.where(
        (i) => '${i.name} ${i.itemCode}'.toLowerCase().contains(
          query.toLowerCase(),
        ),
      ))
        ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(i.name),
          subtitle: Text('${money(i.salesPrice)} · Stock ${i.currentStock}'),
          onTap: () => _itemDialog(context, store, item: i),
        ),
      for (final p in store.parties.where(
        (p) =>
            '${p.name} ${p.phone}'.toLowerCase().contains(query.toLowerCase()),
      ))
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(p.name),
          subtitle: Text('${p.phone} · ${money(store.partyBalance(p))}'),
          onTap: () => _partyDialog(context, store, party: p),
        ),
      for (final t in store.transactions.where(
        (t) => '${t.number} ${t.partyName}'.toLowerCase().contains(
          query.toLowerCase(),
        ),
      ))
        ListTile(
          leading: const Icon(Icons.receipt_long),
          title: Text(t.number),
          subtitle: Text('${t.partyName} · ${money(t.total)}'),
          onTap: () => previewDocument(context, store, t),
        ),
    ],
  );
}

Future<void> switchBusiness(BuildContext context, AppStore store) async {
  final name = TextEditingController();
  await showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('My businesses'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: Text(store.company.name),
                subtitle: const Text('Active business'),
              ),
              for (final entry
                  in (store.remoteMode
                      ? store.remoteBusinesses
                            .where((b) => '${b['id']}' != store.company.id)
                            .map((b) => MapEntry('${b['id']}', {'company': b}))
                      : store.firms.entries.where(
                          (e) => e.key != store.company.id,
                        )))
                ListTile(
                  title: Text('${entry.value['company']['name']}'),
                  onTap: () async {
                    await store.switchFirm(entry.key);
                    if (c.mounted) Navigator.pop(c);
                  },
                ),
              const Divider(),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'New business name',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            await store.addFirm(name.text);
            if (c.mounted) Navigator.pop(c);
          },
          child: const Text('Add business'),
        ),
      ],
    ),
  );
  name.dispose();
}

Future<void> backupDialog(BuildContext context, AppStore store) async {
  final input = TextEditingController();
  String? error;
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Business backup'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Export the active business as JSON. To restore a Flutter backup, paste its JSON below. Restoring replaces this business’s current records.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: input,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Backup JSON'),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              final bytes = Uint8List.fromList(
                utf8.encode(jsonEncode(store.snapshot())),
              );
              await SharePlus.instance.share(
                ShareParams(
                  files: [XFile.fromData(bytes, mimeType: 'application/json')],
                  fileNameOverrides: ['empiran-backup.json'],
                ),
              );
            },
            child: const Text('Export JSON'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final data = Map<String, dynamic>.from(jsonDecode(input.text));
                // Parse into an isolated store first, so invalid input cannot change live data.
                final check = AppStore();
                check.restore(data);
                check.dispose();
                final approved = await showDialog<bool>(
                  context: c,
                  builder: (d) => AlertDialog(
                    title: const Text('Replace current business data?'),
                    content: const Text(
                      'Export a backup first if you need to keep the current records.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('Restore'),
                      ),
                    ],
                  ),
                );
                if (approved != true) return;
                data['company']['id'] = store.company.id;
                store.restore(data);
                await store.persist();
                if (c.mounted) Navigator.pop(c);
              } catch (e) {
                set(() => error = 'Invalid backup: $e');
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    ),
  );
  input.dispose();
}

class CatalogPage extends StatefulWidget {
  const CatalogPage(this.store, {super.key, this.parties = false});
  final AppStore store;
  final bool parties;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String query = '';
  bool lowOnly = false;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: widget.parties ? 'Customers & Suppliers' : 'Products & Inventory',
    subtitle: widget.parties
        ? 'Contacts, GST details and account statements'
        : 'Product catalogue, pricing and stock management',
    action: FilledButton.icon(
      onPressed: () => widget.parties
          ? _partyDialog(context, widget.store)
          : _itemDialog(context, widget.store),
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    ),
    child: Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search by name, code, category or phone',
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        if (!widget.parties)
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Low stock only'),
              selected: lowOnly,
              onSelected: (v) => setState(() => lowOnly = v),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: widget.parties
                ? [
                    for (final p in widget.store.parties.where(
                      (p) => '${p.name} ${p.phone} ${p.type}'
                          .toLowerCase()
                          .contains(query.toLowerCase()),
                    ))
                      Card(
                        child: ExpansionTile(
                          title: Text(p.name),
                          subtitle: Text(
                            '${p.type} · ${p.phone} · ${money(widget.store.partyBalance(p))}',
                          ),
                          children: [
                            ListTile(
                              title: Text(p.address),
                              subtitle: Text('${p.email} · ${p.gstin}'),
                            ),
                            Wrap(
                              children: [
                                TextButton(
                                  onPressed: () => _partyDialog(
                                    context,
                                    widget.store,
                                    party: p,
                                  ),
                                  child: const Text('Edit'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    if (await confirmDelete(
                                      context,
                                      'Delete ${p.name}? Existing documents will be retained.',
                                    )) {
                                      await widget.store.deleteParty(p);
                                    }
                                  },
                                  child: const Text('Delete'),
                                ),
                                for (final type in [
                                  'payment_in',
                                  'payment_out',
                                ])
                                  TextButton(
                                    onPressed: () => openComposer(
                                      context,
                                      widget.store,
                                      type,
                                      source: BusinessTransaction(
                                        id: '',
                                        type: type,
                                        number: '',
                                        date: DateTime.now(),
                                        lines: [],
                                        partyId: p.id,
                                        partyName: p.name,
                                        partyPhone: p.phone,
                                      ),
                                    ),
                                    child: Text(transactionLabels[type]!),
                                  ),
                              ],
                            ),
                            for (final t in widget.store.transactions.where(
                              (t) =>
                                  t.partyId == p.id ||
                                  (t.partyId == null && t.partyName == p.name),
                            ))
                              ListTile(
                                title: Text(
                                  '${t.number} · ${transactionLabels[t.type] ?? t.type}',
                                ),
                                trailing: Text(money(t.total)),
                                onTap: () =>
                                    previewDocument(context, widget.store, t),
                              ),
                          ],
                        ),
                      ),
                  ]
                : [
                    for (final i in widget.store.items.where(
                      (i) =>
                          (!lowOnly || i.currentStock <= i.lowStockLimit) &&
                          '${i.name} ${i.itemCode} ${i.category}'
                              .toLowerCase()
                              .contains(query.toLowerCase()),
                    ))
                      Card(
                        child: ListTile(
                          leading: _ProductImage(i.image),
                          title: Text(i.name),
                          subtitle: Text(
                            '${i.category} · ${money(i.salesPrice)}\n${i.isService ? 'Service' : '${i.currentStock} ${i.unit} in stock'}',
                          ),
                          isThreeLine: true,
                          onTap: () =>
                              _itemDialog(context, widget.store, item: i),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await _itemDialog(
                                  context,
                                  widget.store,
                                  item: i,
                                );
                              }
                              if (v == 'delete' &&
                                  context.mounted &&
                                  await confirmDelete(
                                    context,
                                    'Delete ${i.name}? Existing documents will be retained.',
                                  )) {
                                await widget.store.deleteItem(i);
                              }
                              if (v == 'stock' && context.mounted) {
                                await adjustStock(context, widget.store, i);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              if (!i.isService)
                                const PopupMenuItem(
                                  value: 'stock',
                                  child: Text('Adjust stock'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
          ),
        ),
      ],
    ),
  );
}

Future<void> adjustStock(
  BuildContext context,
  AppStore store,
  Item item,
) async {
  final controller = TextEditingController();
  String? error;
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text('Adjust ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current stock: ${item.currentStock}. Use a negative quantity to remove stock.',
            ),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Quantity change'),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(controller.text);
              if (value == null || !value.isFinite) {
                set(() => error = 'Enter a valid quantity.');
                return;
              }
              await store.changeStock(item, value);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

String money(num value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: 'INR ').format(value);

const transactionLabels = <String, String>{
  'quotation': 'Quotations',
  'order': 'Orders & Invoices',
  'sale_order': 'Sale Orders',
  'sale_return': 'Sale Returns',
  'purchase_bill': 'Purchase Bills',
  'purchase_order': 'Purchase Orders',
  'purchase_return': 'Purchase Returns',
  'payment_in': 'Payment In',
  'payment_out': 'Payment Out',
};

Future<void> previewDocument(
  BuildContext context,
  AppStore store,
  BusinessTransaction t,
) => showDialog(
  context: context,
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

Future<void> shareDocument(BuildContext context, BusinessTransaction t) async {
  final phone = t.partyPhone.replaceAll(RegExp(r'[^0-9]'), '');
  final uri = Uri.https('wa.me', '/$phone', {
    'text':
        'Hello ${t.partyName.isEmpty ? 'Customer' : t.partyName}, ${transactionLabels[t.type] ?? t.type} ${t.number}: ${money(t.total)}. Thank you!',
  });
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open WhatsApp.')));
  }
}

class TransactionPage extends StatefulWidget {
  const TransactionPage(this.store, this.type, {super.key});
  final AppStore store;
  final String type;
  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  String query = '', status = 'All';
  DateTimeRange? range;
  @override
  Widget build(BuildContext context) {
    final data = widget.store.transactions
        .where(
          (t) =>
              (t.type == widget.type ||
                  (widget.type == 'order' && t.type == 'sale_invoice')) &&
              '${t.number} ${t.partyName} ${t.partyPhone}'
                  .toLowerCase()
                  .contains(query.toLowerCase()) &&
              (status == 'All' ||
                  t.status.toLowerCase() == status.toLowerCase()) &&
              (range == null ||
                  (!t.date.isBefore(range!.start) &&
                      t.date.isBefore(
                        range!.end.add(const Duration(days: 1)),
                      ))),
        )
        .toList();
    return PageFrame(
      title: transactionLabels[widget.type]!,
      subtitle:
          '${data.length} records · Total ${money(data.fold<double>(0, (s, t) => s + t.total))}',
      action: FilledButton.icon(
        onPressed: () => openComposer(context, widget.store, widget.type),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search number, name or phone',
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final s in ['All', 'Paid', 'Unpaid', 'Partial'])
                FilterChip(
                  label: Text(s),
                  selected: status == s,
                  onSelected: (_) => setState(() => status = s),
                ),
              TextButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                  range == null
                      ? 'Date range'
                      : '${DateFormat.yMd().format(range!.start)} – ${DateFormat.yMd().format(range!.end)}',
                ),
                onPressed: () async {
                  final value = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (mounted && value != null) setState(() => range = value);
                },
              ),
              if (range != null)
                IconButton(
                  tooltip: 'Clear dates',
                  onPressed: () => setState(() => range = null),
                  icon: const Icon(Icons.clear),
                ),
            ],
          ),
          Expanded(
            child: data.isEmpty
                ? const Center(
                    child: Text(
                      'No transactions found. Create one to get started.',
                    ),
                  )
                : ListView.separated(
                    itemCount: data.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final t = data[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${t.number} · ${t.partyName.isEmpty ? 'Cash Customer' : t.partyName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${DateFormat.yMMMd().format(t.date)} · ${t.isGst ? 'GST' : 'Non-GST'} · ${t.status}',
                              ),
                              Text(
                                '${money(t.total)} · Balance ${money(t.balance)}',
                              ),
                              Wrap(
                                spacing: 6,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => previewDocument(
                                      context,
                                      widget.store,
                                      t,
                                    ),
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: const Text('PDF / Print / Share'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => shareDocument(context, t),
                                    icon: const Icon(Icons.chat_outlined),
                                    label: const Text('WhatsApp'),
                                  ),
                                  if (widget.type == 'quotation')
                                    TextButton(
                                      onPressed:
                                          widget.store.transactions.any(
                                            (x) => x.convertedFrom == t.id,
                                          )
                                          ? null
                                          : () => openComposer(
                                              context,
                                              widget.store,
                                              'order',
                                              source: t,
                                            ),
                                      child: Text(
                                        widget.store.transactions.any(
                                              (x) => x.convertedFrom == t.id,
                                            )
                                            ? 'Converted'
                                            : 'Convert to order',
                                      ),
                                    ),
                                  IconButton(
                                    tooltip: 'Delete transaction',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      if (await confirmDelete(
                                        context,
                                        'Delete ${t.number}? Stock changes will be reversed.',
                                      )) {
                                        await widget.store.deleteTransaction(t);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmDelete(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete record'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> openComposer(
  BuildContext context,
  AppStore store,
  String type, {
  BusinessTransaction? source,
}) async {
  final saved = await Navigator.push<BusinessTransaction>(
    context,
    MaterialPageRoute(
      builder: (_) => InvoiceComposer(store, type, source: source),
    ),
  );
  if (saved != null && context.mounted) {
    await previewDocument(context, store, saved);
  }
}

class InvoiceComposer extends StatefulWidget {
  const InvoiceComposer(
    this.store,
    this.type, {
    super.key,
    this.source,
    this.embedded = false,
  });
  final AppStore store;
  final String type;
  final BusinessTransaction? source;
  final bool embedded;
  @override
  State<InvoiceComposer> createState() => _InvoiceComposerState();
}

class _InvoiceComposerState extends State<InvoiceComposer> {
  final lines = <InvoiceLine>[];
  final name = TextEditingController(),
      phone = TextEditingController(),
      notes = TextEditingController();
  String? partyId;
  String query = '', category = 'All', paymentMode = 'Cash';
  double discount = 0, shipping = 0, paid = 0, amount = 0;
  bool gst = false, busy = false, percentageDiscount = false;
  final dispatch = <String, String>{};
  String? error;
  DateTime date = DateTime.now();
  bool get payment => widget.type.startsWith('payment_');
  double get subtotal =>
      payment ? amount : lines.fold(0, (s, l) => s + l.total);
  double get effectiveDiscount =>
      percentageDiscount ? subtotal * discount / 100 : discount;
  double get total =>
      (subtotal - effectiveDiscount) * (gst ? 1.18 : 1) + shipping;
  @override
  void initState() {
    super.initState();
    final source = widget.source;
    if (source != null) {
      lines.addAll(source.lines.map((l) => InvoiceLine.fromJson(l.toJson())));
      name.text = source.partyName;
      phone.text = source.partyPhone;
      partyId = source.partyId;
      discount = source.discount;
      shipping = source.shipping;
      notes.text = source.notes;
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    notes.dispose();
    super.dispose();
  }

  void add(Item item) => setState(() {
    final index = lines.indexWhere((l) => l.itemId == item.id);
    if (index >= 0) {
      lines[index].quantity++;
    } else {
      lines.add(
        InvoiceLine(
          itemId: item.id,
          name: item.name,
          quantity: 1,
          unit: item.unit,
          price: widget.type.startsWith('purchase')
              ? item.purchasePrice
              : item.salesPrice,
          hsn: item.hsn,
        ),
      );
    }
  });
  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (payment && (partyId == null || amount <= 0)) {
        throw ArgumentError(
          'Select a party and enter an amount greater than zero.',
        );
      }
      final t = await widget.store.create(
        gst: gst,
        type: widget.type,
        lines: payment
            ? [
                InvoiceLine(
                  itemId: '',
                  name: transactionLabels[widget.type]!,
                  quantity: 1,
                  unit: '',
                  price: amount,
                ),
              ]
            : lines,
        partyId: partyId,
        partyName: name.text.trim(),
        partyPhone: phone.text.trim(),
        date: date,
        paid: payment ? 0 : paid,
        discount: effectiveDiscount,
        dispatch: dispatch,
        shipping: shipping,
        paymentMode: paymentMode,
        notes: notes.text,
        convertedFrom: widget.source?.type == 'quotation'
            ? widget.source?.id
            : null,
      );
      if (mounted) {
        if (widget.embedded) {
          await previewDocument(context, widget.store, t);
          if (mounted) {
            setState(() {
              lines.clear();
            });
          }
        } else {
          Navigator.pop(context, t);
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget numeric(String label, double value, ValueChanged<double> changed) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          initialValue: '$value',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          onChanged: (v) =>
              setState(() => changed(double.tryParse(v) ?? double.nan)),
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Create ${transactionLabels[widget.type]}')),
    body: LayoutBuilder(
      builder: (_, c) {
        final products = Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search products, codes or HSN',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final cat in {
                    'All',
                    ...widget.store.items.map((i) => i.category),
                  })
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: category == cat,
                        onSelected: (_) => setState(() => category = cat),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: widget.store.items.isEmpty
                  ? Center(
                      child: TextButton.icon(
                        onPressed: () async {
                          await _itemDialog(context, widget.store);
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add your first product'),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final i in widget.store.items.where(
                          (i) =>
                              (category == 'All' || i.category == category) &&
                              '${i.name} ${i.itemCode} ${i.hsn}'
                                  .toLowerCase()
                                  .contains(query.toLowerCase()),
                        ))
                          Card(
                            child: ListTile(
                              leading: _ProductImage(i.image),
                              title: Text(i.name),
                              subtitle: Text(
                                '${money(widget.type.startsWith('purchase') ? i.purchasePrice : i.salesPrice)} · Stock ${i.currentStock} ${i.unit}',
                              ),
                              trailing: const Icon(Icons.add_circle_outline),
                              onTap: () => add(i),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
        final cart = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Customer / Supplier',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            DropdownButtonFormField<String>(
              initialValue: partyId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Choose saved party',
              ),
              items: widget.store.parties
                  .map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                partyId = v;
                final p = widget.store.parties.firstWhere((p) => p.id == v);
                name.text = p.name;
                phone.text = p.phone;
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name (optional)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(DateFormat.yMMMd().format(date)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => date = d);
              },
            ),
            if (payment) numeric('Payment amount', amount, (v) => amount = v),
            for (final l in lines)
              Card(
                key: ObjectKey(l),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove line',
                            onPressed: () => setState(() => lines.remove(l)),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: numeric(
                              'Quantity (${l.unit})',
                              l.quantity,
                              (v) => l.quantity = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: numeric(
                              'Unit price',
                              l.price,
                              (v) => l.price = v,
                            ),
                          ),
                        ],
                      ),
                      Text(money(l.total)),
                    ],
                  ),
                ),
              ),
            if (!payment) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('GST order (CGST 9% + SGST 9%)'),
                value: gst,
                onChanged: (v) => setState(() => gst = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Discount as percentage'),
                value: percentageDiscount,
                onChanged: (v) => setState(() {
                  percentageDiscount = v;
                  discount = 0;
                }),
              ),
              KeyedSubtree(
                key: ValueKey(percentageDiscount),
                child: numeric(
                  percentageDiscount ? 'Discount (%)' : 'Discount amount',
                  discount,
                  (v) => discount = v,
                ),
              ),
              numeric('Shipping charges', shipping, (v) => shipping = v),
              numeric('Paid amount', paid, (v) => paid = v),
            ],
            DropdownButtonFormField<String>(
              initialValue: paymentMode,
              decoration: const InputDecoration(labelText: 'Payment mode'),
              items: [
                'Cash',
                'Bank',
                'UPI',
                'Cheque',
                'Card',
              ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => paymentMode = v!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes / terms'),
              maxLines: 2,
            ),
            if (!payment && widget.type != 'quotation')
              ExpansionTile(
                title: const Text('Dispatch & delivery details'),
                children: [
                  for (final field in const {
                    'deliveryNote': 'Delivery note',
                    'reference': 'Reference no. / date',
                    'otherReferences': 'Other references',
                    'buyersOrderNo': 'Buyer order number',
                    'buyersOrderDate': 'Buyer order date',
                    'dispatchDocNo': 'Dispatch document number',
                    'deliveryNoteDate': 'Delivery note date',
                    'transportMode': 'Dispatched through',
                    'destination': 'Destination',
                    'lrNo': 'Bill of lading / LR number',
                    'vehicleNo': 'Motor vehicle number',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextFormField(
                        initialValue: dispatch[field.key],
                        decoration: InputDecoration(labelText: field.value),
                        onChanged: (v) => dispatch[field.key] = v,
                      ),
                    ),
                ],
              ),
            const Divider(height: 30),
            Text('Subtotal: ${money(subtotal)}'),
            if (gst)
              Text(
                'CGST + SGST: ${money((subtotal - effectiveDiscount) * .18)}',
              ),
            Text(
              'Total: ${money(total)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!payment) Text('Balance: ${money(total - paid)}'),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : save,
              icon: const Icon(Icons.save_outlined),
              label: Text(busy ? 'Saving…' : 'Save & preview PDF'),
            ),
          ],
        );
        if (payment) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: cart,
            ),
          );
        }
        if (c.maxWidth >= 800) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(flex: 3, child: products),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: Card(child: cart)),
              ],
            ),
          );
        }
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  const Tab(text: 'Products'),
                  Tab(text: 'Cart (${lines.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    Padding(padding: const EdgeInsets.all(12), child: products),
                    cart,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage(this.store, {super.key});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final sales = store.transactions.where(
      (t) => t.type == 'order' || t.type == 'sale_invoice',
    );
    final purchases = store.transactions.where(
      (t) => t.type == 'purchase_bill',
    );
    return PageFrame(
      title: 'Business Dashboard',
      subtitle: 'Sales, purchases, stock and party balances at a glance.',
      child: ListView(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final metric in [
                ('Total sales', sales.fold<double>(0, (s, t) => s + t.total)),
                ('Purchases', purchases.fold<double>(0, (s, t) => s + t.total)),
                (
                  'Receivables',
                  store.parties.fold<double>(
                    0,
                    (s, p) =>
                        s + store.partyBalance(p).clamp(0, double.infinity),
                  ),
                ),
                (
                  'Expenses',
                  store.expenses.fold<double>(
                    0,
                    (s, e) => s + (e['amount'] as num).toDouble(),
                  ),
                ),
              ])
                SizedBox(
                  width: 230,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(metric.$1),
                          Text(
                            money(metric.$2),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final type in [
                'order',
                'purchase_bill',
                'payment_in',
                'payment_out',
              ])
                FilledButton.tonal(
                  onPressed: () => openComposer(context, store, type),
                  child: Text(transactionLabels[type]!),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Low stock', style: Theme.of(context).textTheme.titleLarge),
          for (final item in store.items.where(
            (i) => !i.isService && i.currentStock <= i.lowStockLimit,
          ))
            ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.orange),
              title: Text(item.name),
              trailing: Text('${item.currentStock} ${item.unit}'),
            ),
          const SizedBox(height: 24),
          Text(
            'Recent transactions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final t in store.transactions.take(10))
            ListTile(
              title: Text('${t.number} · ${t.partyName}'),
              subtitle: Text(transactionLabels[t.type] ?? t.type),
              trailing: Text(money(t.total)),
              onTap: () => previewDocument(context, store, t),
            ),
        ],
      ),
    );
  }
}

class RecordsPage extends StatefulWidget {
  const RecordsPage(this.store, {super.key, this.bank = false});
  final AppStore store;
  final bool bank;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  String query = '';
  List<Map<String, dynamic>> get records =>
      widget.bank ? widget.store.bankAccounts : widget.store.expenses;
  Future<void> edit([Map<String, dynamic>? record]) async {
    final fields = widget.bank
        ? [
            'Account name',
            'Bank name',
            'Account number',
            'IFSC',
            'Opening balance',
          ]
        : ['Expense name', 'Category', 'Amount', 'Payment mode', 'Notes'];
    final controllers = {
      for (final f in fields)
        f: TextEditingController(text: '${record?[f] ?? ''}'),
    };
    DateTime date = DateTime.tryParse('${record?['date']}') ?? DateTime.now();
    String? error;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(widget.bank ? 'Bank account' : 'Expense'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final f in fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: controllers[f],
                        decoration: InputDecoration(labelText: f),
                      ),
                    ),
                  if (!widget.bank)
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: c,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) set(() => date = d);
                      },
                      child: Text(DateFormat.yMMMd().format(date)),
                    ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final value = double.tryParse(
                  controllers[widget.bank ? 'Opening balance' : 'Amount']!.text,
                );
                if (controllers[fields.first]!.text.trim().isEmpty ||
                    value == null ||
                    !value.isFinite ||
                    (!widget.bank && value <= 0)) {
                  set(() => error = 'Enter a name and valid amount.');
                  return;
                }
                final result = <String, dynamic>{
                  for (final f in fields) f: controllers[f]!.text.trim(),
                  'id':
                      record?['id'] ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  'amount': value,
                  'date': date.toIso8601String(),
                };
                try {
                  if (widget.bank) {
                    await widget.store.saveBankAccount(result);
                  } else {
                    await widget.store.saveExpense(result);
                  }
                  if (record != null) {
                    await widget.store.deleteRecord(record, bank: widget.bank);
                  }
                  if (c.mounted) Navigator.pop(c);
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
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: widget.bank ? 'Cash & Bank Accounts' : 'Expenses',
    subtitle:
        'Total ${money(records.fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble()))}',
    action: FilledButton.icon(
      onPressed: edit,
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    ),
    child: Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search records',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final r in records.where(
                (r) => r.values
                    .join(' ')
                    .toLowerCase()
                    .contains(query.toLowerCase()),
              ))
                Card(
                  child: ListTile(
                    title: Text(
                      '${r[widget.bank ? 'Account name' : 'Expense name']}',
                    ),
                    subtitle: Text(
                      widget.bank
                          ? '${r['Bank name']} · ${r['Account number']} · ${r['IFSC']}'
                          : '${r['Category']} · ${DateFormat.yMMMd().format(DateTime.parse(r['date']))}',
                    ),
                    trailing: Text(money(r['amount'] as num)),
                    onTap: () => edit(r),
                    leading: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await confirmDelete(
                          context,
                          'Delete this record?',
                        )) {
                          await widget.store.deleteRecord(r, bank: widget.bank);
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
