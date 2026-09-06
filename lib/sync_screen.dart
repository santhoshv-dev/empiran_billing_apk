import 'package:flutter/material.dart';
import 'app_store.dart';
import 'data/local/db_helper.dart';

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
    final pending = _queue.where((q) => q['status'] == 'pending' || q['status'] == 'failed').toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronization Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: widget.store.syncing ? null : () => widget.store.syncEngine.syncNow(),
            tooltip: 'Sync Now',
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildStatusHeader(pending.length),
              Expanded(
                child: ListView.builder(
                  itemCount: _queue.length,
                  itemBuilder: (context, index) {
                    final item = _queue[index];
                    final isPending = item['status'] == 'pending' || item['status'] == 'failed';
                    return ListTile(
                      leading: Icon(
                        item['operation'] == 'CREATE' ? Icons.add_circle_outline
                        : item['operation'] == 'UPDATE' ? Icons.edit_outlined
                        : Icons.delete_outline,
                        color: isPending ? Colors.orange : Colors.green,
                      ),
                      title: Text('${item['operation']} ${item['entityType'].toString().toUpperCase()}'),
                      subtitle: Text(
                        isPending 
                          ? 'Status: ${item['status']}' + (item['errorMessage'] != null ? '\nError: ${item['errorMessage']}' : '')
                          : 'Synced successfully',
                        style: TextStyle(
                          color: item['status'] == 'failed' ? Colors.red : null,
                        ),
                      ),
                      isThreeLine: item['status'] == 'failed',
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildStatusHeader(int pendingCount) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Row(
        children: [
          Icon(
            widget.store.remoteMode ? Icons.cloud_done : Icons.cloud_off,
            size: 48,
            color: widget.store.remoteMode ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.store.remoteMode ? 'Online Mode' : 'Offline Mode',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  pendingCount > 0 
                    ? '$pendingCount items waiting to sync'
                    : 'All data is synchronized',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (widget.store.syncing)
            const CircularProgressIndicator()
        ],
      ),
    );
  }
}
