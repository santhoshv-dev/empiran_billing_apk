import 'dart:convert';

double _d(dynamic value) => (value as num?)?.toDouble() ?? 0;

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
      ifsc;
  String? logo;
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
    this.currentStock = 0,
    this.lowStockLimit = 5,
    this.image,
  });
  String id, name, category, itemCode, hsn, unit;
  double salesPrice, currentStock, lowStockLimit;
  String? image;
  factory Item.fromJson(Map<String, dynamic> j) => Item(
    id: '${j['id']}',
    name: j['name'] ?? '',
    category: j['category'] ?? 'General',
    itemCode: j['itemCode'] ?? '',
    hsn: j['hsn'] ?? '',
    unit: j['unit'] ?? 'Pcs',
    salesPrice: _d(j['salesPrice']),
    currentStock: _d(j['currentStock']),
    lowStockLimit: _d(j['lowStockLimit']),
    image: j['image'] ?? j['imageUrl'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'itemCode': itemCode,
    'hsn': hsn,
    'unit': unit,
    'salesPrice': salesPrice,
    'currentStock': currentStock,
    'lowStockLimit': lowStockLimit,
    'image': image,
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
  DateTime date;
  List<InvoiceLine> lines;
  bool isGst;
  double paid;
  Map<String, String> dispatch;
  double get subtotal => lines.fold(0, (a, b) => a + b.total);
  double get cgst => isGst ? subtotal * .09 : 0;
  double get sgst => isGst ? subtotal * .09 : 0;
  double get total => subtotal + cgst + sgst;
  double get balance => total - paid;
  factory BusinessTransaction.fromJson(Map<String, dynamic> j) =>
      BusinessTransaction(
        id: '${j['id']}',
        type: j['type'] ?? j['txnType'] ?? 'order',
        number: j['number'] ?? j['txnNo'] ?? '',
        date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
        lines: ((j['lines'] ?? j['lineItems'] ?? []) as List)
            .map((e) => InvoiceLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        partyName: j['partyName'] ?? '',
        partyPhone: j['partyPhone'] ?? '',
        partyAddress: j['partyAddress'] ?? '',
        partyGstin: j['partyGstin'] ?? '',
        isGst: j['isGst'] ?? (_d(j['cgst']) > 0),
        paid: _d(j['paid'] ?? j['paidAmount']),
        paymentMode: j['paymentMode'] ?? 'Cash',
        status: j['status'] ?? 'Unpaid',
        dispatch: Map<String, String>.from(j['dispatch'] ?? {}),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'number': number,
    'date': date.toIso8601String(),
    'lines': lines.map((e) => e.toJson()).toList(),
    'partyName': partyName,
    'partyPhone': partyPhone,
    'partyAddress': partyAddress,
    'partyGstin': partyGstin,
    'isGst': isGst,
    'paid': paid,
    'paymentMode': paymentMode,
    'status': status,
    'dispatch': dispatch,
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
