import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';

class StaffManagementTab extends StatelessWidget {
  final List<Map<String, String>> users;

  const StaffManagementTab({super.key, required this.users});

  void _showUserDialog(BuildContext context, [Map<String, String>? user]) {
    final isEdit = user != null;
    final name = TextEditingController(text: user?['name'] ?? '');
    final username = TextEditingController(text: user?['username'] ?? '');
    final email = TextEditingController(text: user?['email'] ?? '');
    final password = TextEditingController();
    String role = user?['role'] ?? 'Biller';
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEdit ? 'Edit Staff Member' : 'Add Staff Member'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmpiranTextField(
                    controller: name,
                    label: 'Full Name',
                    isRequired: true,
                  ),
                  const SizedBox(height: 12),
                  EmpiranTextField(
                    controller: username,
                    label: 'Username',
                    isRequired: !isEdit,
                    enabled: !isEdit,
                  ),
                  const SizedBox(height: 12),
                  EmpiranTextField(
                    controller: email,
                    label: 'Email Address',
                  ),
                  const SizedBox(height: 12),
                  EmpiranTextField(
                    controller: password,
                    label: isEdit ? 'New Password (Optional)' : 'Password',
                    obscureText: true,
                    isRequired: !isEdit,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: ['Admin', 'Manager', 'Biller'].contains(role) ? role : 'Biller',
                    decoration: const InputDecoration(labelText: 'Staff Role'),
                    items: const [
                      DropdownMenuItem(value: 'Admin', child: Text('Administrator (Full Control)')),
                      DropdownMenuItem(value: 'Manager', child: Text('Manager (Reports & Billing)')),
                      DropdownMenuItem(value: 'Biller', child: Text('Biller (Billing Only)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => role = v);
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            EmpiranButton(
              label: isEdit ? 'Update' : 'Create',
              onPressed: () {
                if (name.text.trim().isEmpty || (!isEdit && (username.text.trim().isEmpty || password.text.isEmpty))) {
                  setState(() => error = 'Name, username, and password are required.');
                  return;
                }

                if (isEdit) {
                  context.read<SettingsBloc>().add(
                        UpdateStaffUserRequested(
                          id: user['id'],
                          username: user['username']!,
                          name: name.text.trim(),
                          email: email.text.trim(),
                          password: password.text.isNotEmpty ? password.text : null,
                          role: role,
                        ),
                      );
                } else {
                  context.read<SettingsBloc>().add(
                        CreateStaffUserRequested(
                          name: name.text.trim(),
                          username: username.text.trim(),
                          email: email.text.trim(),
                          password: password.text,
                          role: role,
                        ),
                      );
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    ).then((_) {
      name.dispose();
      username.dispose();
      email.dispose();
      password.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;

        return Column(
          children: [
            if (isNarrow) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Staff Accounts & Access',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Authorized billers, managers and administrators',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  EmpiranButton(
                    label: 'Add Staff Member',
                    icon: Icons.person_add_outlined,
                    onPressed: () => _showUserDialog(context),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff Accounts & Access',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Authorized billers, managers and administrators',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  EmpiranButton(
                    label: 'Add Staff Member',
                    icon: Icons.person_add_outlined,
                    onPressed: () => _showUserDialog(context),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (users.isEmpty)
              Expanded(
                child: EmpiranEmptyState(
                  title: 'No staff accounts configured',
                  description: 'Add staff members to grant billing or administrative access.',
                  icon: Icons.manage_accounts_outlined,
                  actionLabel: 'Add Staff Member',
                  onAction: () => _showUserDialog(context),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final isCardCompact = cardConstraints.maxWidth < 520;

                        final avatar = CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            (u['name']?.isNotEmpty ?? false) ? u['name']![0].toUpperCase() : 'U',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        );

                        final userInfo = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${u['username']} • ${u['email'] ?? 'No email'}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );

                        final roleBadge = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadii.small),
                          ),
                          child: Text(
                            u['role'] ?? 'Biller',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        );

                        final actions = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit Staff',
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showUserDialog(context, u),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                              onPressed: () {
                                context
                                    .read<SettingsBloc>()
                                    .add(DeleteStaffUserRequested(
                                      u['username']!,
                                      id: u['id'],
                                    ));
                              },
                            ),
                          ],
                        );

                        if (isCardCompact) {
                          return EmpiranCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    avatar,
                                    const SizedBox(width: 12),
                                    Expanded(child: userInfo),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Divider(height: 1),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    roleBadge,
                                    actions,
                                  ],
                                ),
                              ],
                            ),
                          );
                        }

                        return EmpiranCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              avatar,
                              const SizedBox(width: 14),
                              Expanded(child: userInfo),
                              roleBadge,
                              const SizedBox(width: 8),
                              actions,
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
    );
  }
}
