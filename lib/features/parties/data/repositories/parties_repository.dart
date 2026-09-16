import '../../../../data/local/db_helper.dart';
import '../../../../data/remote/api_client.dart';
import '../../../../models.dart';

class PartiesRepository {
  final ApiClient apiClient;

  PartiesRepository({required this.apiClient});

  Future<List<Party>> loadParties() async {
    final localRows = await DbHelper.instance.queryAll('parties');
    final parties = localRows.map((r) => Party.fromJson(r)).toList();

    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final companyId = await apiClient.getActiveBusinessId();
        if (companyId != null) {
          final remoteRows = await apiClient.getParties(companyId);
          final remoteParties = remoteRows.map((r) => Party.fromJson(r)).toList();

          for (final party in remoteParties) {
            await DbHelper.instance.insertOrUpdate('parties', party.toJson(), party.id);
          }
          return remoteParties;
        }
      } catch (_) {}
    }

    return parties;
  }

  Future<void> saveParty(Party party) async {
    await DbHelper.instance.insertOrUpdate('parties', party.toJson(), party.id);

    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final companyId = await apiClient.getActiveBusinessId();
        if (companyId != null) {
          await apiClient.createParty(companyId, party.toJson());
        }
      } catch (_) {}
    }
  }

  Future<void> deleteParty(Party party) async {
    await DbHelper.instance.delete('parties', party.id);

    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final companyId = await apiClient.getActiveBusinessId();
        if (companyId != null) {
          await apiClient.deleteParty(companyId, party.id);
        }
      } catch (_) {}
    }
  }
}
