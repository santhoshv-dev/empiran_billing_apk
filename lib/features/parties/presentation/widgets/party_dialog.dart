import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../../../../models.dart';
import '../bloc/parties_bloc.dart';
import '../bloc/parties_event.dart';

void showPartyDialog(BuildContext context, {Party? party, String? defaultType}) {
  final n = TextEditingController(text: party?.name ?? '');
  final ph = TextEditingController(text: party?.phone ?? '');
  final em = TextEditingController(text: party?.email ?? '');
  final gst = TextEditingController(text: party?.gstin ?? '');
  final address = TextEditingController(text: party?.address ?? '');
  final balance = TextEditingController(text: '${party?.balance ?? 0}');
  String type = party?.type ?? defaultType ?? 'Customer';
  String? error;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(party == null ? 'New Contact Account' : 'Edit Contact Account'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Customer', label: Text('Customer')),
                    ButtonSegment(value: 'Supplier', label: Text('Supplier')),
                    ButtonSegment(value: 'Both', label: Text('Both')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => set(() => type = s.first),
                ),
                const SizedBox(height: 16),
                EmpiranTextField(
                  controller: n,
                  label: 'Contact / Business Name',
                  isRequired: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: ph,
                        label: 'Mobile / Phone',
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: em,
                        label: 'Email',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: gst,
                        label: 'GSTIN / Tax ID',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: balance,
                        label: 'Opening Balance (₹)',
                        hint: '0.00',
                        isNumber: true,
                        isDecimal: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                EmpiranTextField(
                  controller: address,
                  label: 'Billing & Shipping Address',
                  maxLines: 2,
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
          if (party != null)
            TextButton(
              onPressed: () {
                context.read<PartiesBloc>().add(DeletePartyRequested(party));
                Navigator.pop(ctx);
              },
              child: const Text('Delete', style: TextStyle(color: AppColors.error)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          EmpiranButton(
            label: 'Save Contact',
            onPressed: () {
              if (n.text.trim().isEmpty || ph.text.trim().isEmpty) {
                set(() => error = 'Name and phone are required.');
                return;
              }

              final savedParty = Party(
                id: party?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                name: n.text.trim(),
                phone: ph.text.trim(),
                email: em.text.trim(),
                type: type,
                gstin: gst.text.trim(),
                address: address.text.trim(),
                balance: double.tryParse(balance.text) ?? 0,
              );

              context.read<PartiesBloc>().add(SavePartyRequested(savedParty));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );

  Future.delayed(const Duration(milliseconds: 500), () {
    for (final c in [n, ph, em, gst, address, balance]) {
      c.dispose();
    }
  });
}
