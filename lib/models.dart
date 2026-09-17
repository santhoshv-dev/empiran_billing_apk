import 'dart:convert';

double _d(dynamic value) => (value as num?)?.toDouble() ?? 0;
bool _b(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return false;
}
String _transactionType(dynamic value) => switch ('$value') {
      'sale_invoice' => 'order',
      'estimate' => 'quotation',
      final value => value,
    };
String _apiTransactionType(String value) => switch (value) {
      'order' => 'sale_invoice',
      'quotation' => 'estimate',
      'purchase' => 'purchase_bill',
      final value => value,
    };
Map<String, dynamic> _transactionMeta(dynamic value) {
  if (value is! String || !value.trimLeft().startsWith('{')) return {};
  try {
    return Map<String, dynamic>.from(jsonDecode(value));
  } catch (_) {
    return {};
  }
}

List<InvoiceLine> _parseLines(dynamic raw) {
  if (raw == null) return [];
  if (raw is String) {
    if (raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => InvoiceLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }
  if (raw is List) {
    return raw
        .map((e) => InvoiceLine.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  return [];
}

Map<String, String> _parseDispatch(dynamic raw, dynamic notes) {
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
  }
  final meta = _transactionMeta(notes)['dispatch'];
  if (meta is Map) {
    return meta.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
  return {};
}

class Company {
  Company({
    this.id = 'local',
    this.name = 'Empiran Traders',
    this.gstin = '',
    this.address = '',
    this.phone = '',
    this.state = 'Tamil Nadu',
    this.stateCode = '33',
    this.email = '',
    this.bankName = '',
    this.accountNo = '',
    this.branch = '',
    this.ifsc = '',
    this.logo,
    this.role = 'Owner',
  });
  String id,
      name,
      gstin,
      address,
      phone,
      state,
      stateCode,
      email,
      bankName,
      accountNo,
      branch,
      ifsc,
      role;
  String? logo;
  String get displayName {
    final value = name.trim();
    if (value.isEmpty || value == '1') return 'Empiran Traders';
    return value;
  }

  factory Company.fromJson(Map<String, dynamic> j) => Company(
        id: '${j['id'] ?? 'local'}',
        name: j['name'] ?? 'Empiran Traders',
        gstin: j['gstin'] ?? '',
        address: j['address'] ?? j['addressLine1'] ?? '',
        phone: j['phone'] ?? '',
        state: j['state'] ?? 'Tamil Nadu',
        stateCode: j['stateCode'] ?? '33',
        email: j['email'] ?? '',
        bankName: j['bankName'] ?? '',
        accountNo: j['accountNo'] ?? '',
        branch: j['branch'] ?? '',
        ifsc: j['ifsc'] ?? '',
        logo: j['logo'],
        role: j['role'] ?? 'Owner',
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gstin': gstin,
        'address': address,
        'phone': phone,
        'state': state,
        'stateCode': stateCode,
        'email': email,
        'bankName': bankName,
        'accountNo': accountNo,
        'branch': branch,
        'ifsc': ifsc,
        'logo': logo,
        'role': role,
      };
  Map<String, dynamic> toApiJson() => {
        'name': name,
        'legalName': name,
        'gstin': gstin,
        'pan': null,
        'phone': phone,
        'email': email,
        'addressLine1': address,
        'addressLine2': null,
        'city': state,
        'stateCode': stateCode,
        'pincode': null,
        'invoicePrefix': 'INV',
        'defaultTerms': null,
      };
}

class Item {
  Item({
    required this.id,
    required this.name,
    this.category = 'General',
    this.itemCode = '',
    this.hsn = '',
    this.unit = 'Pcs',
    this.salesPrice = 0,
    this.purchasePrice = 0,
    this.isService = false,
    this.currentStock = 0,
    this.lowStockLimit = 5,
    this.image,
  });
  String id, name, category, itemCode, hsn, unit;
  double salesPrice, purchasePrice, currentStock, lowStockLimit;
  bool isService;
  String? image;
  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: '${j['id']}',
        name: j['name'] ?? '',
        category: j['category'] ?? 'General',
        itemCode: j['itemCode'] ?? '',
        hsn: j['hsn'] ?? '',
        unit: j['unit'] ?? 'Pcs',
        salesPrice: _d(j['salesPrice']),
        purchasePrice: _d(j['purchasePrice']),
        isService: _b(j['isService']),
        currentStock: _d(j['currentStock']),
        lowStockLimit: _d(j['lowStockLimit']),
        image: j['image'] ?? j['Image'] ?? j['imageUrl'],
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'itemCode': itemCode,
        'hsn': hsn,
        'unit': unit,
        'salesPrice': salesPrice,
        'purchasePrice': purchasePrice,
        'isService': isService,
        'currentStock': currentStock,
        'lowStockLimit': lowStockLimit,
        'image': image,
      };
  Map<String, dynamic> toApiJson() => {
        'name': name,
        'category': category,
        'itemCode': itemCode,
        'hsn': hsn,
        'unit': unit,
        'salesPrice': salesPrice,
        'purchasePrice': purchasePrice,
        'isService': isService,
        'openingStock': currentStock,
        'currentStock': currentStock,
        'lowStockLimit': lowStockLimit,
        'image': image,
      };
}

class Category {
  Category({
    required this.id,
    required this.name,
  });

  String id, name;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] ?? j['Id'] ?? '',
        name: j['name'] ?? j['Name'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}

class Party {
  Party({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.type = 'Customer',
    this.gstin = '',
    this.address = '',
    this.balance = 0,
  });
  String id, name, phone, email, type, gstin, address;
  double balance;
  factory Party.fromJson(Map<String, dynamic> j) => Party(
        id: '${j['id']}',
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        email: j['email'] ?? '',
        type: j['type'] ?? 'Customer',
        gstin: j['gstin'] ?? '',
        address: j['address'] ?? '',
        balance: _d(j['balance'] ?? j['currentBalance']),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'type': type,
        'gstin': gstin,
        'address': address,
        'balance': balance,
      };
  Map<String, dynamic> toApiJson() => {
        'name': name,
        'phone': phone,
        'email': email,
        'type': type,
        'gstin': gstin,
        'address': address,
        'openingBalance': balance,
      };
}

class InvoiceLine {
  InvoiceLine({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.price,
    this.hsn = '',
  });
  String itemId, name, unit, hsn;
  double quantity, price;
  double get total => quantity * price;
  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
        itemId: '${j['itemId']}',
        name: j['name'] ?? '',
        quantity: _d(j['quantity']),
        unit: j['unit'] ?? 'Pcs',
        price: _d(j['price']),
        hsn: j['hsn'] ?? '',
      );
  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'price': price,
        'hsn': hsn,
        'discountPercent': 0,
        'discountAmount': 0,
        'taxRate': 0,
        'taxAmount': 0,
        'total': total,
      };
  Map<String, dynamic> toApiJson() => {
        'itemId': itemId.trim().isEmpty ? null : itemId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'price': price,
        'hsn': hsn,
        'discountPercent': 0,
        'discountAmount': 0,
        'taxRate': 0,
        'taxAmount': 0,
        'total': total,
      };
}

class BusinessTransaction {
  BusinessTransaction({
    required this.id,
    required this.type,
    required this.number,
    required this.date,
    required this.lines,
    this.partyName = '',
    this.partyPhone = '',
    this.partyAddress = '',
    this.partyGstin = '',
    this.isGst = false,
    this.paid = 0,
    this.paymentMode = 'Cash',
    this.status = 'Unpaid',
    this.dispatch = const {},
    this.partyId,
    this.convertedFrom,
    this.discount = 0,
    this.shipping = 0,
    this.notes = '',
    this.referredBy,
  });
  String id,
      type,
      number,
      partyName,
      partyPhone,
      partyAddress,
      partyGstin,
      paymentMode,
      status;
  String? partyId, convertedFrom, referredBy;
  String notes;
  double discount, shipping;
  DateTime date;
  List<InvoiceLine> lines;
  bool isGst;
  double paid;
  Map<String, String> dispatch;
  double get subtotal => lines.fold(0, (a, b) => a + b.total);
  double get cgst => isGst ? (subtotal - discount) * .09 : 0;
  double get sgst => isGst ? (subtotal - discount) * .09 : 0;
  double get total => subtotal - discount + cgst + sgst + shipping;
  double get balance => total - paid;
  factory BusinessTransaction.fromJson(
    Map<String, dynamic> j,
  ) =>
      BusinessTransaction(
        id: '${j['id']}',
        partyId: j['partyId']?.toString(),
        convertedFrom: (j['convertedFrom'] ?? j['referenceNo'])?.toString(),
        referredBy: j['referredBy']?.toString(),
        discount: _d(j['discount'] ?? j['discountAmount']),
        shipping: _d(j['shipping'] ?? j['shippingCharges']),
        notes: _transactionMeta(j['notes'])['text']?.toString() ??
            j['notes'] ??
            '',
        type: _transactionType(j['type'] ?? j['txnType'] ?? 'order'),
        number: j['number'] ?? j['txnNo'] ?? '',
        date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
        lines: _parseLines(j['lines'] ?? j['lineItems']),
        partyName: j['partyName'] ?? '',
        partyPhone: j['partyPhone'] ?? '',
        partyAddress: j['partyAddress'] ?? '',
        partyGstin: j['partyGstin'] ?? '',
        isGst: _b(j['isGst']) || (_d(j['cgst']) > 0),
        paid: _d(j['paid'] ?? j['paidAmount']),
        paymentMode: j['paymentMode'] ?? 'Cash',
        status: j['status'] ?? 'Unpaid',
        dispatch: _parseDispatch(j['dispatch'], j['notes']),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'number': number,
        'date': date.toIso8601String(),
        'lines': jsonEncode(lines.map((e) => e.toJson()).toList()),
        'partyName': partyName,
        'partyPhone': partyPhone,
        'partyAddress': partyAddress,
        'partyGstin': partyGstin,
        'isGst': isGst,
        'paid': paid,
        'paymentMode': paymentMode,
        'status': status,
        'dispatch': jsonEncode(dispatch),
        'partyId': partyId,
        'convertedFrom': convertedFrom,
        'referredBy': referredBy,
        'discount': discount,
        'shipping': shipping,
        'notes': notes,
      };
  Map<String, dynamic> toApiJson() => {
        'txnType': _apiTransactionType(type),
        'txnNo': number,
        'partyId': partyId,
        'partyName': partyName,
        'date': date.toIso8601String(),
        'dueDate': null,
        'lineItems': lines.map((e) => e.toApiJson()).toList(),
        'subTotal': subtotal,
        'discountPercent': 0,
        'discountAmount': discount,
        'taxTotal': cgst + sgst,
        'cgst': cgst,
        'sgst': sgst,
        'igst': 0,
        'shippingCharges': shipping,
        'grandTotal': total,
        'paidAmount': paid,
        'balanceDue': balance,
        'paymentMode': paymentMode,
        'bankAccountId': null,
        'status': status,
        'referenceNo': convertedFrom,
        'notes': notes,
        'expenseCategory': null,
      };
}

class InvoiceSettings {
  InvoiceSettings({
    this.gstYear = '25-26',
    this.gstCounter = 1,
    this.nonGstPrefix = 'ORD-',
    this.nonGstCounter = 1001,
  });
  String gstYear, nonGstPrefix;
  int gstCounter, nonGstCounter;
  factory InvoiceSettings.fromJson(Map<String, dynamic> j) => InvoiceSettings(
        gstYear: j['gstYear'] ?? '25-26',
        gstCounter: j['gstCounter'] ?? 1,
        nonGstPrefix: j['nonGstPrefix'] ?? 'ORD-',
        nonGstCounter: j['nonGstCounter'] ?? 1001,
      );
  Map<String, dynamic> toJson() => {
        'gstYear': gstYear,
        'gstCounter': gstCounter,
        'nonGstPrefix': nonGstPrefix,
        'nonGstCounter': nonGstCounter,
      };
}

String encodeList(Iterable<Map<String, dynamic>> value) =>
    jsonEncode(value.toList());
