import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../bloc/parties_bloc.dart';
import '../bloc/parties_event.dart';
import '../bloc/parties_state.dart';
import '../widgets/party_dialog.dart';

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
              Row(
                children: [
                  Expanded(
                    child: EmpiranTextField(
                      controller: _searchController,
                      label: '',
                      hint: 'Search contacts by name, phone, GSTIN...',
                      prefixIcon: Icons.search_rounded,
                      onChanged: (_) => _onFilterChanged(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SegmentedButton<String>(
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
                ],
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

                          return EmpiranCard(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    p.name.isNotEmpty ? p.name[0].toUpperCase() : 'C',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            p.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '📞 ${p.phone} • ${p.gstin.isNotEmpty ? 'GSTIN: ${p.gstin}' : (p.email.isNotEmpty ? p.email : 'No GSTIN')}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
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
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  tooltip: 'Edit Contact',
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => showPartyDialog(context, party: p),
                                ),
                              ],
                            ),
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
