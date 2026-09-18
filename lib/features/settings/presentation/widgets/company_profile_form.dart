import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../../../../models.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';

class CompanyProfileForm extends StatefulWidget {
  final Company company;

  const CompanyProfileForm({super.key, required this.company});

  @override
  State<CompanyProfileForm> createState() => _CompanyProfileFormState();
}

class _CompanyProfileFormState extends State<CompanyProfileForm>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final Map<String, TextEditingController> _controllers;
  String? _logo;
  Uint8List? _logoBytes;
  bool _isLogoLoading = false;

  @override
  void initState() {
    super.initState();
    _logo = widget.company.logo;
    if (_logo != null && _logo!.isNotEmpty) {
      try {
        _logoBytes = base64Decode(_logo!.contains(',') ? _logo!.split(',').last : _logo!);
      } catch (_) {}
    }
    _controllers = {
      'name': TextEditingController(text: widget.company.name),
      'gstin': TextEditingController(text: widget.company.gstin),
      'phone': TextEditingController(text: widget.company.phone),
      'email': TextEditingController(text: widget.company.email),
      'address': TextEditingController(text: widget.company.address),
      'state': TextEditingController(text: widget.company.state),
      'stateCode': TextEditingController(text: widget.company.stateCode),
      'bankName': TextEditingController(text: widget.company.bankName),
      'accountNo': TextEditingController(text: widget.company.accountNo),
      'branch': TextEditingController(text: widget.company.branch),
      'ifsc': TextEditingController(text: widget.company.ifsc),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (['name', 'gstin', 'address', 'phone']
        .any((k) => _controllers[k]!.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all mandatory fields (*).')),
      );
      return;
    }

    final updated = Company(
      id: widget.company.id,
      name: _controllers['name']!.text.trim(),
      gstin: _controllers['gstin']!.text.trim(),
      address: _controllers['address']!.text.trim(),
      phone: _controllers['phone']!.text.trim(),
      state: _controllers['state']!.text.trim(),
      stateCode: _controllers['stateCode']!.text.trim(),
      email: _controllers['email']!.text.trim(),
      bankName: _controllers['bankName']!.text.trim(),
      accountNo: _controllers['accountNo']!.text.trim(),
      branch: _controllers['branch']!.text.trim(),
      ifsc: _controllers['ifsc']!.text.trim(),
      logo: _logo,
      role: widget.company.role,
    );

    context.read<SettingsBloc>().add(SaveCompanyRequested(updated));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Company profile saved successfully.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SingleChildScrollView(
      child: EmpiranCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Identity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'These details appear on your invoices, tax receipts, and payment drafts.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final inputWidth = constraints.maxWidth < 680
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 2 > 320
                        ? 320.0
                        : (constraints.maxWidth - 16) / 2;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final x in [
                      ('name', 'Company Name', true),
                      ('gstin', 'GSTIN / UIN', true),
                      ('phone', 'Primary Contact / Mobile', true),
                      ('email', 'Official Email', false),
                      ('address', 'Business Address', true),
                      ('state', 'State Name', false),
                      ('stateCode', 'State Code (e.g. 33)', false),
                      ('bankName', 'Bank Name', false),
                      ('accountNo', 'Bank Account Number', false),
                      ('branch', 'Bank Branch', false),
                      ('ifsc', 'Bank IFSC Code', false),
                    ])
                      SizedBox(
                        width: inputWidth,
                        child: EmpiranTextField(
                          controller: _controllers[x.$1],
                          label: x.$2,
                          isRequired: x.$3,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Company Logo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_isLogoLoading) ...[
                  const SizedBox(
                    width: 54,
                    height: 54,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  const SizedBox(width: 14),
                ] else if (_logoBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    child: Image.memory(
                      _logoBytes!,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                EmpiranButton(
                  label: _logo == null ? 'Upload Logo' : 'Change Logo',
                  icon: Icons.upload_file_outlined,
                  variant: EmpiranButtonVariant.outlined,
                  onPressed: _isLogoLoading ? null : () async {
                    setState(() => _isLogoLoading = true);
                    try {
                      final f = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 75,
                        maxWidth: 1200,
                      );
                      if (f != null) {
                        final bytes = await f.readAsBytes();
                        final base64String = base64Encode(bytes);
                        if (mounted) {
                          setState(() {
                            _logoBytes = bytes;
                            _logo = base64String;
                          });
                        }
                      }
                    } finally {
                      if (mounted) setState(() => _isLogoLoading = false);
                    }
                  },
                ),
                if (_logo != null && !_isLogoLoading) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Remove Logo',
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: () => setState(() {
                      _logo = null;
                      _logoBytes = null;
                    }),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerRight,
              child: EmpiranButton(
                label: 'Save Business Profile',
                icon: Icons.save_outlined,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
