import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/core/widgets/empiran_components.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';
import 'package:empiran/models.dart';
import '../bloc/products_bloc.dart';
import '../bloc/products_event.dart';

void showProductDialog(BuildContext context, {Item? item, String? initialCategory}) {
  final name = TextEditingController(text: item?.name ?? '');
  final hsn = TextEditingController(text: item?.hsn ?? '');
  final code = TextEditingController(text: item?.itemCode ?? '');
  final purchase = TextEditingController(text: '${item?.purchasePrice ?? 0}');
  final sales = TextEditingController(text: '${item?.salesPrice ?? 0}');
  final stock = TextEditingController(text: '${item?.currentStock ?? 0}');
  final unit = TextEditingController(text: item?.unit ?? 'Pcs');
  final low = TextEditingController(text: '${item?.lowStockLimit ?? 5}');
  bool isService = item?.isService ?? false;
  String? image = item?.image;

  final settingsState = context.read<SettingsBloc>().state;
  final categories = settingsState is SettingsLoaded ? settingsState.categories : ['General'];
  String selectedCat = item?.category ?? initialCategory ?? 'General';
  if (!categories.contains(selectedCat)) selectedCat = categories.isNotEmpty ? categories.first : 'General';
  String? error;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(item == null ? 'Create New Product' : 'Edit Product'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCat,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    if (v != null) set(() => selectedCat = v);
                  },
                ),
                const SizedBox(height: 12),
                EmpiranTextField(
                  controller: name,
                  label: 'Product Name',
                  hint: 'e.g. LED Downlight 15W',
                  isRequired: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: code,
                        label: 'SKU / Barcode',
                        hint: 'Item code',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: hsn,
                        label: 'HSN Code',
                        hint: 'e.g. 8539',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: sales,
                        label: 'Selling Price (₹)',
                        hint: '0.00',
                        isNumber: true,
                        isDecimal: true,
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: purchase,
                        label: 'Purchase Cost (₹)',
                        hint: '0.00',
                        isNumber: true,
                        isDecimal: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: stock,
                        label: 'Current Stock',
                        hint: '0',
                        isNumber: true,
                        isDecimal: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: unit,
                        label: 'Unit of Measure',
                        hint: 'Pcs, Mtr, Box, Kg',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: low,
                        label: 'Low Stock Alert',
                        hint: '5',
                        isNumber: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('This is a service (no inventory tracking)', style: TextStyle(fontSize: 13)),
                  value: isService,
                  onChanged: (v) => set(() => isService = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (image != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        child: Image.memory(
                          base64Decode(image!.contains(',') ? image!.split(',').last : image!),
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    EmpiranButton(
                      label: image == null ? 'Add Image' : 'Change Image',
                      icon: Icons.photo_library_outlined,
                      variant: EmpiranButtonVariant.outlined,
                      height: 40,
                      onPressed: () async {
                        final f = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 70,
                          maxWidth: 1000,
                        );
                        if (f != null) {
                          final bytes = await f.readAsBytes();
                          set(() => image = base64Encode(bytes));
                        }
                      },
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (item != null)
            TextButton(
              onPressed: () {
                context.read<ProductsBloc>().add(DeleteProductRequested(item));
                Navigator.pop(ctx);
              },
              child: const Text('Delete', style: TextStyle(color: AppColors.error)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          EmpiranButton(
            label: 'Save Product',
            onPressed: () {
              if (name.text.trim().isEmpty ||
                  double.tryParse(sales.text) == null ||
                  double.tryParse(purchase.text) == null ||
                  double.tryParse(stock.text) == null) {
                set(() => error = 'Please enter valid details and numeric values.');
                return;
              }

              final savedItem = Item(
                id: item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.text.trim(),
                hsn: hsn.text.trim(),
                itemCode: code.text.trim(),
                purchasePrice: double.parse(purchase.text),
                salesPrice: double.parse(sales.text),
                currentStock: double.parse(stock.text),
                category: selectedCat,
                unit: unit.text.trim().isEmpty ? 'Pcs' : unit.text.trim(),
                lowStockLimit: double.tryParse(low.text) ?? 5,
                isService: isService,
                image: image,
              );

              context.read<ProductsBloc>().add(SaveProductRequested(savedItem));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );

  Future.delayed(const Duration(milliseconds: 500), () {
    for (final c in [name, hsn, code, purchase, sales, stock, unit, low]) {
      c.dispose();
    }
  });
}
