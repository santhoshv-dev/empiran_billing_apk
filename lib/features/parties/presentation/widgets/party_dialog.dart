import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../../../../models.dart';
import '../bloc/parties_bloc.dart';
import '../bloc/parties_event.dart';

void showPartyDialog(BuildContext context,
    {Party? party, String? defaultType}) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<PartiesBloc>(),
      child: _PartyDialog(party: party, defaultType: defaultType),
    ),
  );
}

class _PartyDialog extends StatefulWidget {
  const _PartyDialog({this.party, this.defaultType});
  final Party? party;
  final String? defaultType;

  @override
  State<_PartyDialog> createState() => _PartyDialogState();
}

class _PartyDialogState extends State<_PartyDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _gstin;
  late final TextEditingController _address;
  late final TextEditingController _balance;
  late String _type;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.party;
    _name = TextEditingController(text: p?.name ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _gstin = TextEditingController(text: p?.gstin ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _balance = TextEditingController(text: '${p?.balance ?? 0}');
    _type = p?.type ?? widget.defaultType ?? 'Customer';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _gstin.dispose();
    _address.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _error = 'Name and phone are required.');
      return;
    }
    final savedParty = Party(
      id: widget.party?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      type: _type,
      gstin: _gstin.text.trim(),
      address: _address.text.trim(),
      balance: double.tryParse(_balance.text) ?? 0,
    );
    context.read<PartiesBloc>().add(SavePartyRequested(savedParty));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.party != null;
    final isNarrow = MediaQuery.sizeOf(context).width < 560;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Contact Account' : 'New Contact Account',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'Customer', label: Text('Customer')),
                          ButtonSegment(
                              value: 'Supplier', label: Text('Supplier')),
                          ButtonSegment(value: 'Both', label: Text('Both')),
                        ],
                        selected: {_type},
                        onSelectionChanged: (s) =>
                            setState(() => _type = s.first),
                      ),
                    ),
                    const SizedBox(height: 16),
                    EmpiranTextField(
                      controller: _name,
                      label: 'Contact / Business Name',
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    if (isNarrow) ...[
                      EmpiranTextField(
                        controller: _phone,
                        label: 'Mobile / Phone',
                        isRequired: true,
                      ),
                      const SizedBox(height: 12),
                      EmpiranTextField(
                        controller: _email,
                        label: 'Email',
                      ),
                      const SizedBox(height: 12),
                      EmpiranTextField(
                        controller: _gstin,
                        label: 'GSTIN / Tax ID',
                      ),
                      const SizedBox(height: 12),
                      EmpiranTextField(
                        controller: _balance,
                        label: 'Opening Balance (₹)',
                        hint: '0.00',
                        isNumber: true,
                        isDecimal: true,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: EmpiranTextField(
                              controller: _phone,
                              label: 'Mobile / Phone',
                              isRequired: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EmpiranTextField(
                              controller: _email,
                              label: 'Email',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: EmpiranTextField(
                              controller: _gstin,
                              label: 'GSTIN / Tax ID',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EmpiranTextField(
                              controller: _balance,
                              label: 'Opening Balance (₹)',
                              hint: '0.00',
                              isNumber: true,
                              isDecimal: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    EmpiranTextField(
                      controller: _address,
                      label: 'Billing & Shipping Address',
                      maxLines: 2,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  if (isEdit)
                    TextButton(
                      onPressed: () {
                        context
                            .read<PartiesBloc>()
                            .add(DeletePartyRequested(widget.party!));
                        Navigator.pop(context);
                      },
                      child: const Text('Delete',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  EmpiranButton(
                    label: 'Save Contact',
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
