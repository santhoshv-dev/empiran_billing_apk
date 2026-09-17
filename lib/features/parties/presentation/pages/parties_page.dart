import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../bloc/parties_bloc.dart';
import '../bloc/parties_event.dart';
import '../bloc/parties_state.dart';
import '../widgets/party_dialog.dart';
import '../../../../models.dart';

class PartiesPage extends StatefulWidget {
  const PartiesPage({super.key});

  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  final _searchController = TextEditingController();
  String _filter = 'All'; // 'All', 'Customers', 'Suppliers'

  @override
  void initState() {
    super.initState();
    context.read<PartiesBloc>().add(const LoadPartiesRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    context.read<PartiesBloc>().add(
          FilterPartiesRequested(
            query: _searchController.text.trim(),
            partyFilter: _filter,
          ),
        );
  }

  Future<void> _deleteParty(Party p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Contact'),
          ],
        ),
        content: Text('Are you sure you want to delete ${p.name}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<PartiesBloc>().add(DeletePartyRequested(p));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${p.name} deleted successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Customers & Suppliers',
      subtitle: 'Manage client accounts, vendor contacts, and running balances.',
      action: EmpiranButton(
        label: 'Add Contact',
        icon: Icons.person_add_outlined,
        onPressed: () => showPartyDialog(context),
      ),
      child: BlocBuilder<PartiesBloc, PartiesState>(
        builder: (context, state) {
          if (state is PartiesLoading || state is PartiesInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PartiesFailure) {
            return Center(child: Text('Error: ${state.message}'));
          }

          final loaded = state as PartiesLoaded;

          return Column(
            children: [
              // Filter controls
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 640;
                  final searchField = EmpiranTextField(
                    controller: _searchController,
                    label: '',
                    hint: 'Search contacts by name, phone, GSTIN...',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (_) => _onFilterChanged(),
                  );

                  final segmentedFilter = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'All', label: Text('All')),
                        ButtonSegment(value: 'Customers', label: Text('Customers')),
                        ButtonSegment(value: 'Suppliers', label: Text('Suppliers')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (s) {
                        setState(() => _filter = s.first);
                        _onFilterChanged();
                      },
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 10),
                        segmentedFilter,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 14),
                      segmentedFilter,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Parties List
              Expanded(
                child: loaded.filteredParties.isEmpty
                    ? EmpiranEmptyState(
                        title: 'No contacts registered',
                        description: 'Add your clients or suppliers to assign invoices and track payments.',
                        icon: Icons.groups_outlined,
                        actionLabel: 'Add Contact',
                        onAction: () => showPartyDialog(context),
                      )
                    : ListView.separated(
                        itemCount: loaded.filteredParties.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final p = loaded.filteredParties[i];
                          final isReceivable = p.balance > 0;
                          final isPayable = p.balance < 0;

                          return LayoutBuilder(
                            builder: (context, cardConstraints) {
                              final isCompact = cardConstraints.maxWidth < 540;

                              final contactNameRow = Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (p.type == 'Customer'
                                              ? AppColors.primary
                                              : p.type == 'Supplier'
                                                  ? AppColors.secondary
                                                  : Colors.purple)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      p.type,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: p.type == 'Customer'
                                            ? AppColors.primary
                                            : p.type == 'Supplier'
                                                ? AppColors.secondary
                                                : Colors.purple,
                                      ),
                                    ),
                                  ),
                                ],
                              );

                              final detailsColumn = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  contactNameRow,
                                  const SizedBox(height: 3),
                                  Text(
                                    '📞 ${p.phone} • ${p.gstin.isNotEmpty ? 'GSTIN: ${p.gstin}' : (p.email.isNotEmpty ? p.email : 'No GSTIN')}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              );

                              final balanceColumn = Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Formatters.money(p.balance.abs()),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: isReceivable
                                          ? AppColors.success
                                          : isPayable
                                              ? AppColors.error
                                              : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    isReceivable
                                        ? 'Receivable'
                                        : isPayable
                                            ? 'Payable'
                                            : 'Settled',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              );

                              final avatar = CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                child: Text(
                                  p.name.isNotEmpty ? p.name[0].toUpperCase() : 'C',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              );

                              if (isCompact) {
                                return EmpiranCard(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          avatar,
                                          const SizedBox(width: 12),
                                          Expanded(child: detailsColumn),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Divider(height: 1),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          balanceColumn,
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit Contact',
                                                icon: const Icon(Icons.edit_outlined, size: 18),
                                                onPressed: () => showPartyDialog(context, party: p),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete Contact',
                                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                                onPressed: () => _deleteParty(p),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return EmpiranCard(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                child: Row(
                                  children: [
                                    avatar,
                                    const SizedBox(width: 14),
                                    Expanded(child: detailsColumn),
                                    balanceColumn,
                                    const SizedBox(width: 12),
                                    IconButton(
                                      tooltip: 'Edit Contact',
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      onPressed: () => showPartyDialog(context, party: p),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete Contact',
                                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                      onPressed: () => _deleteParty(p),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
