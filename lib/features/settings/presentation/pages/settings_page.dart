import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:empiran/core/widgets/empiran_components.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';
import 'package:empiran/features/settings/presentation/widgets/company_profile_form.dart';
import 'package:empiran/features/settings/presentation/widgets/invoice_sequence_form.dart';
import 'package:empiran/features/settings/presentation/widgets/staff_management_tab.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Settings & Administration',
      subtitle:
          'Company profile, invoice numbering sequences, and staff permissions.',
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoading || state is SettingsInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SettingsFailure) {
            return Center(child: Text('Error: ${state.message}'));
          }

          final loaded = state as SettingsLoaded;

          return Column(
            children: [
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(
                    text: 'Company Profile',
                    icon: Icon(Icons.business_outlined),
                  ),
                  Tab(
                    text: 'Invoice Control',
                    icon: Icon(Icons.pin_outlined),
                  ),
                  Tab(
                    text: 'Staff & Roles',
                    icon: Icon(Icons.manage_accounts_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    CompanyProfileForm(company: loaded.company),
                    InvoiceSequenceForm(settings: loaded.invoiceSettings),
                    StaffManagementTab(users: loaded.users),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
