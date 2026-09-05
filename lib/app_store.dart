import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  Company company = Company();
  InvoiceSettings settings = InvoiceSettings();
  List<Item> items = [];
  List<Party> parties = [];
  List<BusinessTransaction> transactions = [];
  List<Map<String, String>> users = [
    {
      'name': 'Administrator',
      'username': 'empirantraders',
      'email': '',
      'role': 'Admin',
    },
  ];
  bool ready = false;
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    Map<String, dynamic>? map(String k) {
      final v = p.getString(k);
      return v == null ? null : Map<String, dynamic>.from(jsonDecode(v));
    }

    List<Map<String, dynamic>> list(String k) {
      final v = p.getString(k);
      return v == null
          ? []
          : (jsonDecode(v) as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
    }

    final c = map('company');
    if (c != null) company = Company.fromJson(c);
    final s = map('settings');
    if (s != null) settings = InvoiceSettings.fromJson(s);
    items = list('items').map(Item.fromJson).toList();
    parties = list('parties').map(Party.fromJson).toList();
    transactions = list(
      'transactions',
    ).map(BusinessTransaction.fromJson).toList();
    final u = list('users');
    if (u.isNotEmpty)
      users = u.map((e) => e.map((k, v) => MapEntry(k, '$v'))).toList();
    ready = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setString('company', jsonEncode(company.toJson())),
      p.setString('settings', jsonEncode(settings.toJson())),
      p.setString('items', encodeList(items.map((e) => e.toJson()))),
      p.setString('parties', encodeList(parties.map((e) => e.toJson()))),
      p.setString(
        'transactions',
        encodeList(transactions.map((e) => e.toJson())),
      ),
      p.setString('users', jsonEncode(users)),
    ]);
    notifyListeners();
  }

  Future<void> saveCompany() => _save();
  Future<void> saveSettings() => _save();
  Future<void> addItem(Item value) async {
    items.add(value);
    await _save();
  }

  Future<void> addParty(Party value) async {
    parties.add(value);
    await _save();
  }

  Future<void> addUser(Map<String, String> value) async {
    users.add(value);
    await _save();
  }

  Future<BusinessTransaction> create({
    required bool gst,
    required String type,
    required List<InvoiceLine> lines,
    String partyName = '',
    String partyPhone = '',
    bool deductStock = true,
  }) async {
    final no = gst
        ? '${settings.gstCounter}/${settings.gstYear}'
        : '${settings.nonGstPrefix}${settings.nonGstCounter}';
    final t = BusinessTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      number: no,
      date: DateTime.now(),
      lines: lines.map((e) => InvoiceLine.fromJson(e.toJson())).toList(),
      partyName: partyName,
      partyPhone: partyPhone,
      isGst: gst,
    );
    transactions.insert(0, t);
    if (deductStock) {
      for (final l in lines) {
        final i = items.indexWhere((x) => x.id == l.itemId);
        if (i >= 0)
          items[i].currentStock = (items[i].currentStock - l.quantity).clamp(
            0,
            double.infinity,
          );
      }
    }
    if (gst) {
      settings.gstCounter++;
    } else {
      settings.nonGstCounter++;
    }
    await _save();
    return t;
  }
}
