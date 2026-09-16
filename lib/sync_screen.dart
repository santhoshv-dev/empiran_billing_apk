import 'package:flutter/material.dart';
import 'app_store.dart';
import 'data/local/db_helper.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/empiran_components.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen(this.store, {super.key});
  final AppStore store;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  List<Map<String, dynamic>> _queue = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQueue();
    widget.store.addListener(_loadQueue);
  }

  @override
  void dispose() {
    widget.store.removeListener(_loadQueue);
    super.dispose();
  }

  Future<void> _loadQueue() async {
    final queue = await DbHelper.instance.queryAll('sync_queue');
    if (mounted) {
      setState(() {
        _queue = queue.toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pending = _queue
        .where((q) => q['status'] == 'pending' || q['status'] == 'failed')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronization Status'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: EmpiranButton(
              label: widget.store.syncing ? 'Syncing…' : 'Sync Now',
              icon: Icons.sync,
              isLoading: widget.store.syncing,
              height: 38,
              onPressed: widget.store.syncing
                  ? null
                  : () => widget.store.syncEngine.syncNow(),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(context, pending.length),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Change Queue (${_queue.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      if (pending.isNotEmpty)
                        EmpiranStatusChip(
                          label: '${pending.length} Waiting to Sync',
                          type: EmpiranStatusType.warning,
                          small: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _queue.isEmpty
                        ? const EmpiranEmptyState(
                            title: 'All Data is Synchronized',
                            description:
                                'Local database is fully in sync with the cloud server.',
                            icon: Icons.cloud_done_outlined,
                          )
                        : ListView.separated(
                            itemCount: _queue.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _queue[index];
                              final isFailed = item['status'] == 'failed';
                              final isPending = item['status'] == 'pending';

                              IconData opIcon = Icons.add_circle_outline;
                              Color opColor = AppColors.success;
                              if (item['operation'] == 'UPDATE') {
                                opIcon = Icons.edit_outlined;
                                opColor = AppColors.info;
                              } else if (item['operation'] == 'DELETE') {
                                opIcon = Icons.delete_outline;
                                opColor = AppColors.error;
                              }

                              return EmpiranCard(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: opColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                            AppRadii.medium),
                                      ),
                                      child: Icon(opIcon,
                                          color: opColor, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item['operation']} ${item['entityType'].toString().toUpperCase()}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Entity ID: ${item['entityId'] ?? item['id']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.darkTextMuted
                                                  : AppColors.lightTextMuted,
                                            ),
                                          ),
                                          if (item['errorMessage'] != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Text(
                                                'Error: ${item['errorMessage']}',
                                                style: const TextStyle(
                                                    color: AppColors.error,
                                                    fontSize: 12),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    EmpiranStatusChip(
                                      label: isFailed
                                          ? 'Failed'
                                          : (isPending ? 'Pending' : 'Synced'),
                                      type: isFailed
                                          ? EmpiranStatusType.error
                                          : (isPending
                                              ? EmpiranStatusType.warning
                                              : EmpiranStatusType.success),
                                      small: true,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, int pendingCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = widget.store.remoteMode;

    return EmpiranCard(
      padding: const EdgeInsets.all(20),
      color: isOnline
          ? AppColors.success.withValues(alpha: isDark ? 0.12 : 0.06)
          : AppColors.offline.withValues(alpha: isDark ? 0.12 : 0.06),
      borderColor: isOnline
          ? AppColors.success.withValues(alpha: 0.3)
          : AppColors.offline.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isOnline ? AppColors.success : AppColors.offline)
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              size: 32,
              color: isOnline ? AppColors.success : AppColors.offline,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isOnline ? 'Cloud Online Mode' : 'Local Offline Mode',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isOnline
                            ? AppColors.successDark
                            : AppColors.offline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? AppColors.success : AppColors.offline,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pendingCount > 0
                      ? '$pendingCount changes queued for automatic background upload.'
                      : (isOnline
                          ? 'All records and invoice documents are fully synced with server.'
                          : 'Changes will automatically sync when internet connection is restored.'),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
