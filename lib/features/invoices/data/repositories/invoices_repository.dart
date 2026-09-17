import '../../../../core/services/financial_year_service.dart';
import '../../../../data/local/db_helper.dart';
import '../../../../data/remote/api_client.dart';
import '../../../../models.dart';

class InvoicesRepository {
  final ApiClient apiClient;

  InvoicesRepository({required this.apiClient});

  Future<List<BusinessTransaction>> loadInvoices() async {
    final localRows = await DbHelper.instance.queryAll('transactions');
    final txns = localRows.map((r) => BusinessTransaction.fromJson(r)).toList();

    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final companyId = await apiClient.getActiveBusinessId();
        if (companyId != null) {
          final remoteRows = await apiClient.getTransactions(companyId);
          final remoteTxns =
              remoteRows.map((r) => BusinessTransaction.fromJson(r)).toList();

          for (final t in remoteTxns) {
            await DbHelper.instance.insertOrUpdate('transactions', t.toJson(), t.id);
          }
          return remoteTxns;
        }
      } catch (_) {}
    }

    return txns;
  }

  String generateNumber(String type, bool isGst, InvoiceSettings settings) {
    if (isGst) {
      final fy = FinancialYearService.currentTag();
      final tag = fy.isNotEmpty ? fy : settings.gstYear;
      final num = '${tag.replaceAll('-', '')}/${settings.gstCounter.toString().padLeft(4, '0')}';
      settings.gstCounter++;
      return num;
    } else {
      final num = '${settings.nonGstPrefix}${settings.nonGstCounter}';
      settings.nonGstCounter++;
      return num;
    }
  }

  Future<void> saveTransaction(BusinessTransaction txn) async {
    await DbHelper.instance.insertOrUpdate('transactions', txn.toJson(), txn.id);

    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final companyId = await apiClient.getActiveBusinessId();
        if (companyId != null) {
          if (_isGuid(txn.id)) {
            await apiClient.updateTransaction(
              companyId,
              txn.id,
              txn.toApiJson(),
            );
          } else {
            final saved =
                await apiClient.createTransaction(companyId, txn.toApiJson());
            final remoteTxn = BusinessTransaction.fromJson(saved);
            await DbHelper.instance.delete('transactions', txn.id);
            await DbHelper.instance.insertOrUpdate(
              'transactions',
              remoteTxn.toJson(),
              remoteTxn.id,
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<void> deleteTransaction(BusinessTransaction txn) async {
    await DbHelper.instance.delete('transactions', txn.id);

    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final companyId = await apiClient.getActiveBusinessId();
        if (companyId != null && _isGuid(txn.id)) {
          await apiClient.deleteTransaction(companyId, txn.id);
        }
      } catch (_) {}
    }
  }

  static bool _isGuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value.trim());
}
