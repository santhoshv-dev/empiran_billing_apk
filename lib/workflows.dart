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
                Tab(
                    text: 'Create Quotation / Estimate',
                    icon: Icon(Icons.edit_document)),
                Tab(
                    text: 'Saved Quotations',
                    icon: Icon(Icons.history_outlined)),
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
            'Send direct invoice drafts, payment links, and balance reminders.',
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: EmpiranCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_outlined,
                          size: 32, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Direct Customer Messaging',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Launch a pre-filled WhatsApp conversation with your customer.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  EmpiranTextField(
                    controller: phone,
                    label: 'Customer Phone (with country code)',
                    hint: 'e.g. 919876543210',
                    isNumber: true,
                    isRequired: true,
                  ),
                  const SizedBox(height: 14),
                  EmpiranTextField(
                    controller: message,
                    label: 'Message Draft',
                    hint: 'Enter your message or reminder here…',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 20),
                  EmpiranButton(
                    label: 'Open WhatsApp Draft',
                    icon: Icons.send,
                    onPressed: () async {
                      final clean =
                          phone.text.replaceAll(RegExp(r'[^0-9]'), '');
                      if (clean.isEmpty) return;
                      final uri =
                          Uri.https('wa.me', '/$clean', {'text': message.text});
                      final opened = await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Unable to open WhatsApp.')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tip: To send PDF invoices with full item breakdown, open any saved transaction and tap "WhatsApp".',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
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
  Widget buildSuggestions(BuildContext context) {
    final q = query.trim().toLowerCase();
    final items = store.items.where((i) =>
        '${i.name} ${i.itemCode} ${i.category}'.toLowerCase().contains(q));
    final parties = store.parties.where(
        (p) => '${p.name} ${p.phone} ${p.gstin}'.toLowerCase().contains(q));
    final txns = store.transactions
        .where((t) => '${t.number} ${t.partyName}'.toLowerCase().contains(q));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (items.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('Products & Inventory',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.grey)),
          ),
          for (final i in items.take(5))
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined,
                  color: AppColors.secondary),
              title: Text(i.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${i.category} • SKU: ${i.itemCode.isEmpty ? "N/A" : i.itemCode} • Stock: ${i.currentStock}'),
              trailing: Text(money(i.salesPrice),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.primary)),
              onTap: () => _itemDialog(context, store, item: i),
            ),
          const Divider(),
        ],
        if (parties.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('Customers & Suppliers',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.grey)),
          ),
          for (final p in parties.take(5))
            ListTile(
              leading: const Icon(Icons.person_outline, color: Colors.purple),
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${p.type} • ${p.phone}'),
              trailing: Text(money(store.partyBalance(p)),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: store.partyBalance(p) >= 0
                          ? AppColors.success
                          : AppColors.error)),
              onTap: () => _partyDialog(context, store, party: p),
            ),
          const Divider(),
        ],
        if (txns.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('Invoices & Transactions',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.grey)),
          ),
          for (final t in txns.take(5))
            ListTile(
              leading: const Icon(Icons.receipt_long, color: AppColors.primary),
              title: Text(
                  '${t.number} • ${t.partyName.isEmpty ? "Cash Customer" : t.partyName}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${transactionLabels[t.type] ?? t.type} • ${DateFormat.yMMMd().format(t.date)}'),
              trailing: Text(money(t.total),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => previewDocument(context, store, t),
            ),
        ],
      ],
    );
  }
}

Future<void> switchBusiness(BuildContext context, AppStore store) async {
  final name = TextEditingController();
  await showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Select Active Business Firm'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active business item
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.company.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const Text('Active Firm',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final entry in (store.remoteMode
                  ? store.remoteBusinesses
                      .where((b) => '${b['id']}' != store.company.id)
                      .map((b) => MapEntry('${b['id']}', {'company': b}))
                  : store.firms.entries
                      .where((e) => e.key != store.company.id)))
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text('${entry.value['company']['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () async {
                    await store.switchFirm(entry.key);
                    if (c.mounted) Navigator.pop(c);
                  },
                ),
              const Divider(height: 24),
              EmpiranTextField(
                controller: name,
                label: 'Create New Firm / Branch',
                hint: 'e.g. Empiran Lighting Co.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c), child: const Text('Close')),
        EmpiranButton(
          label: 'Create Firm',
          onPressed: () async {
            if (name.text.trim().isNotEmpty) {
              await store.addFirm(name.text.trim());
              if (c.mounted) Navigator.pop(c);
            }
          },
        ),
      ],
    ),
  );
  Future.delayed(const Duration(milliseconds: 500), () => name.dispose());
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
  String partyFilter = 'All'; // 'All', 'Customers', 'Suppliers'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredParties = widget.store.parties.where((p) {
      final matchesQuery = '${p.name} ${p.phone} ${p.type} ${p.gstin}'
          .toLowerCase()
          .contains(query.toLowerCase());
      if (!matchesQuery) return false;
      if (partyFilter == 'Customers')
        return p.type == 'Customer' || p.type == 'Both';
      if (partyFilter == 'Suppliers')
        return p.type == 'Supplier' || p.type == 'Both';
      return true;
    }).toList();

    return PageFrame(
      title: 'Customers & Suppliers',
      subtitle:
          '${filteredParties.length} business contacts and accounts registered',
      action: EmpiranButton(
        label: 'Add Contact',
        icon: Icons.person_add_outlined,
        onPressed: () => _partyDialog(context, widget.store),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: EmpiranSearchBar(
                  hint: 'Search contacts by name, phone, or GSTIN…',
                  initialValue: query,
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              const SizedBox(width: 12),
              for (final f in ['All', 'Customers', 'Suppliers'])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    label: Text(f),
                    selected: partyFilter == f,
                    onSelected: (_) => setState(() => partyFilter = f),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: filteredParties.isEmpty
                ? EmpiranEmptyState(
                    title: 'No contacts found',
                    description: query.isNotEmpty
                        ? 'No contacts matched "$query".'
                        : 'Add customers and suppliers to track balances and issue invoices.',
                    icon: Icons.groups_outlined,
                    actionLabel: 'Add Contact',
                    onAction: () => _partyDialog(context, widget.store),
                  )
                : ListView.separated(
                    itemCount: filteredParties.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = filteredParties[index];
                      final bal = widget.store.partyBalance(p);
                      final isReceivable = bal >= 0;

                      return EmpiranCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: p.type == 'Supplier'
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : Colors.purple.withValues(alpha: 0.15),
                                  child: Icon(
                                    p.type == 'Supplier'
                                        ? Icons.store_outlined
                                        : Icons.person_outline,
                                    color: p.type == 'Supplier'
                                        ? Colors.orange
                                        : Colors.purple,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16),
                                      ),
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          EmpiranStatusChip(
                                              label: p.type, small: true),
                                          if (p.phone.isNotEmpty)
                                            Text(p.phone,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? AppColors
                                                            .darkTextSecondary
                                                        : AppColors
                                                            .lightTextSecondary)),
                                          if (p.gstin.isNotEmpty)
                                            Text('GSTIN: ${p.gstin}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? AppColors
                                                            .darkTextMuted
                                                        : AppColors
                                                            .lightTextMuted)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      money(bal.abs()),
                                      style: AppTypography.number.copyWith(
                                        color: bal == 0
                                            ? (isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary)
                                            : (isReceivable
                                                ? AppColors.success
                                                : AppColors.error),
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      bal == 0
                                          ? 'Settled'
                                          : (isReceivable
                                              ? 'Receivable'
                                              : 'Payable'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: bal == 0
                                            ? Colors.grey
                                            : (isReceivable
                                                ? AppColors.success
                                                : AppColors.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (p.address.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                p.address,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (p.phone.isNotEmpty) ...[
                                  TextButton.icon(
                                    icon: const Icon(Icons.chat_outlined,
                                        size: 16, color: Colors.green),
                                    label: const Text('WhatsApp',
                                        style: TextStyle(color: Colors.green)),
                                    onPressed: () {
                                      final clean = p.phone
                                          .replaceAll(RegExp(r'[^0-9]'), '');
                                      launchUrl(
                                          Uri.https('wa.me', '/$clean', {
                                            'text':
                                                'Hello ${p.name}, your account balance with ${widget.store.company.name} is ${money(bal)}.',
                                          }),
                                          mode: LaunchMode.externalApplication);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.call_outlined,
                                        size: 16),
                                    label: const Text('Call'),
                                    onPressed: () =>
                                        launchUrl(Uri.parse('tel:${p.phone}')),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                TextButton.icon(
                                  icon: const Icon(Icons.payments_outlined,
                                      size: 16),
                                  label: Text(
                                      p.type == 'Supplier' ? 'Pay' : 'Receive'),
                                  onPressed: () => openComposer(
                                    context,
                                    widget.store,
                                    p.type == 'Supplier'
                                        ? 'payment_out'
                                        : 'payment_in',
                                    source: BusinessTransaction(
                                      id: '',
                                      type: p.type == 'Supplier'
                                          ? 'payment_out'
                                          : 'payment_in',
                                      number: '',
                                      date: DateTime.now(),
                                      lines: [],
                                      partyId: p.id,
                                      partyName: p.name,
                                      partyPhone: p.phone,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Edit Contact',
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _partyDialog(
                                      context, widget.store,
                                      party: p),
                                ),
                                IconButton(
                                  tooltip: 'Delete Contact',
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: AppColors.error),
                                  onPressed: () async {
                                    if (await confirmDelete(context,
                                        'Delete "${p.name}"? Existing invoices will be retained.')) {
                                      await widget.store.deleteParty(p);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
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
        title: const Text('Confirm Deletion'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          EmpiranButton(
            label: 'Delete',
            variant: EmpiranButtonVariant.danger,
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    ) ??
    false;

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
        title: Text('Adjust Stock — ${item.name}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Available Stock: ${item.currentStock} ${item.unit}',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter positive quantity to add stock, or negative to reduce stock.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              EmpiranTextField(
                controller: controller,
                label: 'Stock Quantity Change',
                hint: 'e.g. 10 or -5',
                isNumber: true,
                isDecimal: true,
                isRequired: true,
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          EmpiranButton(
            label: 'Update Stock',
            onPressed: () async {
              final value = double.tryParse(controller.text);
              if (value == null || !value.isFinite) {
                set(() => error = 'Enter a valid quantity number.');
                return;
              }
              await store.changeStock(item, value);
              if (c.mounted) Navigator.pop(c);
            },
          ),
        ],
      ),
    ),
  );
  Future.delayed(const Duration(milliseconds: 500), () => controller.dispose());
}

String money(num value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);

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
  BusinessTransaction t, {
  bool isThermal = false,
}) =>
    showDialog(
      context: context,
      builder: (ctx) {
        bool thermal = isThermal;
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SizedBox(
              width: thermal ? 620 : 920,
              height: 720,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                                  thermal
                                      ? Icons.receipt_long
                                      : Icons.description_outlined,
                                  color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  thermal
                                      ? 'Thermal Receipt (80mm)'
                                      : 'Tax Invoice (A4)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
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
                                    icon: Icon(Icons.print_outlined, size: 16)),
                                ButtonSegment(
                                    value: true,
                                    label: Text('80mm'),
                                    icon: Icon(Icons.receipt_long, size: 16)),
                              ],
                              selected: {thermal},
                              onSelectionChanged: (set) {
                                setState(() => thermal = set.first);
                              },
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
                          ? buildThermalReceiptPdf(store.company, t)
                          : buildInvoicePdf(store.company, t),
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

Future<void> previewThermalReceipt(
  BuildContext context,
  AppStore store,
  BusinessTransaction t,
) =>
    previewDocument(context, store, t, isThermal: true);

Future<void> shareDocument(BuildContext context, BusinessTransaction t) async {
  final phone = t.partyPhone.replaceAll(RegExp(r'[^0-9]'), '');
  final uri = Uri.https('wa.me', '/$phone', {
    'text':
        'Hello ${t.partyName.isEmpty ? 'Customer' : t.partyName}, ${transactionLabels[t.type] ?? t.type} ${t.number}: ${money(t.total)}. Thank you!',
  });
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open WhatsApp.')),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      t.date
                          .isBefore(range!.end.add(const Duration(days: 1))))),
        )
        .toList();

    final totalAmount = data.fold<double>(0, (s, t) => s + t.total);

    return PageFrame(
      title: transactionLabels[widget.type] ?? widget.type,
      subtitle: '${data.length} records • Total Volume: ${money(totalAmount)}',
      action: EmpiranButton(
        label: 'Create ${widget.type == "quotation" ? "Quote" : "Invoice"}',
        icon: Icons.add,
        onPressed: () => openComposer(context, widget.store, widget.type),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: EmpiranSearchBar(
                  hint: 'Search by document #, customer name or phone…',
                  initialValue: query,
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              const SizedBox(width: 12),
              for (final s in ['All', 'Paid', 'Unpaid', 'Partial'])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    label: Text(s),
                    selected: status == s,
                    onSelected: (_) => setState(() => status = s),
                  ),
                ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(range == null
                    ? 'Dates'
                    : '${DateFormat.yMd().format(range!.start)} - ${DateFormat.yMd().format(range!.end)}'),
                onPressed: () async {
                  final val = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (mounted && val != null) setState(() => range = val);
                },
              ),
              if (range != null)
                IconButton(
                  tooltip: 'Clear Date Filter',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => range = null),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? EmpiranEmptyState(
                    title:
                        'No ${transactionLabels[widget.type] ?? "records"} found',
                    description: query.isNotEmpty
                        ? 'No records matched your search query.'
                        : 'Create your first invoice or transaction to get started.',
                    icon: Icons.receipt_long_outlined,
                    actionLabel: 'Create Now',
                    onAction: () =>
                        openComposer(context, widget.store, widget.type),
                  )
                : ListView.separated(
                    itemCount: data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final t = data[i];
                      final isPaid = t.status.toLowerCase() == 'paid';

                      return EmpiranCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: isDark ? 0.2 : 0.1),
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.medium),
                                  ),
                                  child: const Icon(Icons.receipt_outlined,
                                      color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.partyName.isEmpty
                                            ? 'Cash Customer'
                                            : t.partyName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16),
                                      ),
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          Text(
                                            '# ${t.number}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: AppColors.primary),
                                          ),
                                          Text(
                                            DateFormat.yMMMd().format(t.date),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppColors
                                                        .darkTextSecondary
                                                    : AppColors
                                                        .lightTextSecondary),
                                          ),
                                          EmpiranStatusChip(
                                              label: t.isGst
                                                  ? 'GST 18%'
                                                  : 'Non-GST',
                                              small: true),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      money(t.total),
                                      style: AppTypography.number
                                          .copyWith(fontSize: 17),
                                    ),
                                    const SizedBox(height: 4),
                                    EmpiranStatusChip(
                                      label: t.status,
                                      type: isPaid
                                          ? EmpiranStatusType.success
                                          : EmpiranStatusType.warning,
                                      small: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t.balance > 0
                                      ? 'Balance Due: ${money(t.balance)}'
                                      : 'Fully Paid (${t.paymentMode})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: t.balance > 0
                                        ? AppColors.error
                                        : AppColors.success,
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.picture_as_pdf,
                                          size: 16),
                                      label: const Text('PDF Preview'),
                                      onPressed: () => previewDocument(
                                          context, widget.store, t),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      icon: const Icon(Icons.chat_outlined,
                                          size: 16, color: Colors.green),
                                      label: const Text('WhatsApp',
                                          style:
                                              TextStyle(color: Colors.green)),
                                      onPressed: () =>
                                          shareDocument(context, t),
                                    ),
                                    if (widget.type == 'quotation') ...[
                                      const SizedBox(width: 4),
                                      EmpiranButton(
                                        label: widget.store.transactions.any(
                                                (x) => x.convertedFrom == t.id)
                                            ? 'Converted'
                                            : 'Convert to Order',
                                        height: 32,
                                        variant: EmpiranButtonVariant.secondary,
                                        onPressed: widget.store.transactions
                                                .any((x) =>
                                                    x.convertedFrom == t.id)
                                            ? null
                                            : () => openComposer(
                                                context, widget.store, 'order',
                                                source: t),
                                      ),
                                    ],
                                    IconButton(
                                      tooltip: 'Delete Transaction',
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: AppColors.error),
                                      onPressed: () async {
                                        if (await confirmDelete(context,
                                            'Delete transaction #${t.number}?')) {
                                          await widget.store
                                              .deleteTransaction(t);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
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

Future<void> openComposer(
  BuildContext context,
  AppStore store,
  String type, {
  BusinessTransaction? source,
}) async {
  final saved = await Navigator.push<BusinessTransaction>(
    context,
    MaterialPageRoute(
        builder: (_) => InvoiceComposer(store, type, source: source)),
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
            'Select a party and enter an amount greater than zero.');
      }
      if (!payment && lines.isEmpty) {
        throw ArgumentError('Add at least one product to the invoice.');
      }
      final t = await widget.store.create(
        gst: gst,
        type: widget.type,
        lines: payment
            ? [
                InvoiceLine(
                  itemId: '',
                  name: transactionLabels[widget.type] ?? widget.type,
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
        convertedFrom:
            widget.source?.type == 'quotation' ? widget.source?.id : null,
      );
      if (mounted) {
        if (widget.embedded) {
          await previewDocument(context, widget.store, t);
          if (mounted) {
            setState(() {
              lines.clear();
              name.clear();
              phone.clear();
              partyId = null;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                  'Create ${transactionLabels[widget.type] ?? widget.type}'),
            ),
      body: LayoutBuilder(
        builder: (_, c) {
          final isWide = c.maxWidth >= 850;

          // Products Selector Pane
          final productsPane = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmpiranSearchBar(
                hint: 'Search products by name, code or HSN…',
                initialValue: query,
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final cat in {
                      'All',
                      ...widget.store.items.map((i) => i.category)
                    })
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: category == cat,
                          onSelected: (_) => setState(() => category = cat),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: widget.store.items.isEmpty
                    ? EmpiranEmptyState(
                        title: 'No products in catalog',
                        description: 'Add your first product to begin billing.',
                        icon: Icons.inventory_2_outlined,
                        actionLabel: 'Add Product',
                        onAction: () async {
                          await _itemDialog(context, widget.store);
                          if (mounted) setState(() {});
                        },
                      )
                    : ListView.separated(
                        itemCount: widget.store.items
                            .where((i) =>
                                (category == 'All' || i.category == category) &&
                                '${i.name} ${i.itemCode} ${i.hsn}'
                                    .toLowerCase()
                                    .contains(query.toLowerCase()))
                            .length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final item = widget.store.items
                              .where((i) =>
                                  (category == 'All' ||
                                      i.category == category) &&
                                  '${i.name} ${i.itemCode} ${i.hsn}'
                                      .toLowerCase()
                                      .contains(query.toLowerCase()))
                              .toList()[i];
                          final inCart = lines.any((l) => l.itemId == item.id);

                          return EmpiranCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            onTap: () => add(item),
                            child: Row(
                              children: [
                                _ProductImage(item.image),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Stock: ${item.currentStock} ${item.unit} • ${item.category}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      money(widget.type.startsWith('purchase')
                                          ? item.purchasePrice
                                          : item.salesPrice),
                                      style: AppTypography.number.copyWith(
                                          fontSize: 15,
                                          color: AppColors.primary),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: inCart
                                            ? AppColors.success
                                                .withValues(alpha: 0.15)
                                            : AppColors.primary
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(
                                            AppRadii.pill),
                                      ),
                                      child: Text(
                                        inCart ? 'Added ✓' : '+ Add',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: inCart
                                              ? AppColors.success
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );

          // Cart & Billing Checkout Pane
          final cartPane = ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Customer / Party Details',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: partyId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Choose Saved Customer / Supplier'),
                items: widget.store.parties
                    .map((p) => DropdownMenuItem(
                        value: p.id, child: Text('${p.name} (${p.phone})')))
                    .toList(),
                onChanged: (v) => setState(() {
                  partyId = v;
                  if (v != null) {
                    final p = widget.store.parties.firstWhere((p) => p.id == v);
                    name.text = p.name;
                    phone.text = p.phone;
                  }
                }),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: EmpiranTextField(
                        controller: name, label: 'Customer Name (or Cash)'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: EmpiranTextField(
                        controller: phone,
                        label: 'Mobile Number',
                        isNumber: true),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => date = d);
                    },
                    child: Text('Date: ${DateFormat.yMMMd().format(date)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (payment) ...[
                EmpiranTextField(
                  label: 'Payment Amount (₹)',
                  hint: '0.00',
                  isNumber: true,
                  isDecimal: true,
                  isRequired: true,
                  onChanged: (v) =>
                      setState(() => amount = double.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Selected Items (${lines.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    if (lines.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => lines.clear()),
                        child: const Text('Clear All',
                            style: TextStyle(
                                color: AppColors.error, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (lines.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainer
                          : AppColors.lightSurfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: const Center(
                      child: Text(
                          'No items in cart. Select products from the left to begin.'),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final l = lines[i];
                      return EmpiranCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(l.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  icon: const Icon(Icons.close,
                                      size: 18, color: AppColors.error),
                                  onPressed: () =>
                                      setState(() => lines.remove(l)),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // Quantity Stepper
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color:
                                            theme.colorScheme.outlineVariant),
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.small),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon:
                                            const Icon(Icons.remove, size: 16),
                                        onPressed: () {
                                          setState(() {
                                            if (l.quantity > 1) {
                                              l.quantity--;
                                            } else {
                                              lines.remove(l);
                                            }
                                          });
                                        },
                                      ),
                                      Text(
                                        '${l.quantity.toStringAsFixed(0)} ${l.unit}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 16),
                                        onPressed: () =>
                                            setState(() => l.quantity++),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    '@ ${money(l.price)}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary),
                                  ),
                                ),
                                Text(
                                  money(l.total),
                                  style: AppTypography.number
                                      .copyWith(fontSize: 15),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),

                // Calculation Options
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Apply GST (CGST 9% + SGST 9%)',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  value: gst,
                  onChanged: (v) => setState(() => gst = v),
                ),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        label: percentageDiscount
                            ? 'Discount (%)'
                            : 'Discount Amount (₹)',
                        hint: '0',
                        isNumber: true,
                        isDecimal: true,
                        onChanged: (v) =>
                            setState(() => discount = double.tryParse(v) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        const Text('% / ₹', style: TextStyle(fontSize: 12)),
                        Switch(
                          value: percentageDiscount,
                          onChanged: (v) => setState(() {
                            percentageDiscount = v;
                            discount = 0;
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        label: 'Shipping Charges (₹)',
                        hint: '0.00',
                        isNumber: true,
                        isDecimal: true,
                        onChanged: (v) =>
                            setState(() => shipping = double.tryParse(v) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EmpiranTextField(
                        label: 'Paid Amount (₹)',
                        hint: '0.00',
                        isNumber: true,
                        isDecimal: true,
                        onChanged: (v) =>
                            setState(() => paid = double.tryParse(v) ?? 0),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentMode,
                decoration: const InputDecoration(labelText: 'Payment Mode'),
                items: ['Cash', 'Bank', 'UPI', 'Cheque', 'Card']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => paymentMode = v!),
              ),
              const SizedBox(height: 12),
              EmpiranTextField(
                controller: notes,
                label: 'Notes / Terms & Conditions',
                hint:
                    'e.g. Warranty 1 year, goods once sold cannot be returned',
                maxLines: 2,
              ),
              const Divider(height: 28),

              // Summary Box
              EmpiranCard(
                color: isDark
                    ? AppColors.darkSurfaceContainerHighest
                    : AppColors.lightSurfaceContainerHighest
                        .withValues(alpha: 0.5),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:', style: TextStyle(fontSize: 14)),
                        Text(money(subtotal),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    if (effectiveDiscount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount:',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.error)),
                          Text('- ${money(effectiveDiscount)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.error)),
                        ],
                      ),
                    ],
                    if (gst) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('CGST (9%) + SGST (9%):',
                              style: TextStyle(fontSize: 14)),
                          Text(money((subtotal - effectiveDiscount) * 0.18),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                    ],
                    if (shipping > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Shipping:',
                              style: TextStyle(fontSize: 14)),
                          Text(money(shipping),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                    ],
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GRAND TOTAL:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(
                          money(total),
                          style: AppTypography.number
                              .copyWith(fontSize: 20, color: AppColors.primary),
                        ),
                      ],
                    ),
                    if (!payment) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Balance Due:',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: total - paid > 0
                                      ? AppColors.error
                                      : AppColors.success)),
                          Text(money(total - paid),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: total - paid > 0
                                      ? AppColors.error
                                      : AppColors.success)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 16),

              EmpiranButton(
                label: busy ? 'Saving Invoice…' : 'Save & Generate Invoice',
                icon: Icons.check_circle_outline,
                isLoading: busy,
                isFullWidth: true,
                onPressed: busy ? null : save,
              ),
            ],
          );

          if (payment) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: cartPane,
              ),
            );
          }

          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(flex: 3, child: productsPane),
                  const SizedBox(width: 20),
                  Expanded(
                      flex: 2,
                      child: EmpiranCard(
                          padding: EdgeInsets.zero, child: cartPane)),
                ],
              ),
            );
          }

          // Mobile View with Clean Tabs
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    const Tab(
                        text: 'Product Catalog',
                        icon: Icon(Icons.inventory_2_outlined)),
                    Tab(
                        text: 'Cart (${lines.length})',
                        icon: const Icon(Icons.shopping_cart_outlined)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: productsPane),
                      cartPane,
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
}

class DashboardPage extends StatelessWidget {
  const DashboardPage(this.store, {super.key});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return DashboardScreen(
      store: store,
      onNavigate: (_) {},
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
            'Account Name',
            'Bank Name',
            'Account Number',
            'IFSC',
            'Opening Balance'
          ]
        : ['Expense Title', 'Category', 'Amount', 'Payment Mode', 'Notes'];

    final controllers = {
      for (final f in fields)
        f: TextEditingController(text: '${record?[f] ?? ''}')
    };
    DateTime date = DateTime.tryParse('${record?['date']}') ?? DateTime.now();
    String? error;

    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(widget.bank ? 'Bank Account' : 'Expense Entry'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final f in fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: EmpiranTextField(
                        controller: controllers[f],
                        label: f,
                        isNumber: f.contains('Amount') || f.contains('Balance'),
                        isDecimal:
                            f.contains('Amount') || f.contains('Balance'),
                        isRequired: f == fields.first ||
                            f.contains('Amount') ||
                            f.contains('Balance'),
                      ),
                    ),
                  if (error != null)
                    Text(error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            EmpiranButton(
              label: 'Save Record',
              onPressed: () async {
                final value = double.tryParse(
                    controllers[widget.bank ? 'Opening Balance' : 'Amount']!
                        .text);
                if (controllers[fields.first]!.text.trim().isEmpty ||
                    value == null ||
                    !value.isFinite) {
                  set(() => error = 'Enter a valid title and amount.');
                  return;
                }
                final result = <String, dynamic>{
                  for (final f in fields) f: controllers[f]!.text.trim(),
                  'id': record?['id'] ??
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
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: widget.bank ? 'Cash & Bank Accounts' : 'Expense Tracker',
        subtitle:
            'Total recorded: ${money(records.fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble()))}',
        action: EmpiranButton(
          label: 'Add Record',
          icon: Icons.add,
          onPressed: edit,
        ),
        child: Column(
          children: [
            EmpiranSearchBar(
              hint: 'Search records…',
              initialValue: query,
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: [
                  for (final r in records.where((r) => r.values
                      .join(' ')
                      .toLowerCase()
                      .contains(query.toLowerCase())))
                    EmpiranCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                            '${r[widget.bank ? 'Account Name' : 'Expense Title']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          widget.bank
                              ? '${r['Bank Name']} • ${r['Account Number']}'
                              : '${r['Category']} • ${DateFormat.yMMMd().format(DateTime.tryParse('${r['date']}') ?? DateTime.now())}',
                        ),
                        trailing: Text(money(r['amount'] as num),
                            style: AppTypography.number.copyWith(fontSize: 15)),
                        onTap: () => edit(r),
                        leading: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.error),
                          onPressed: () async {
                            if (await confirmDelete(
                                context, 'Delete this record?')) {
                              await widget.store
                                  .deleteRecord(r, bank: widget.bank);
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
