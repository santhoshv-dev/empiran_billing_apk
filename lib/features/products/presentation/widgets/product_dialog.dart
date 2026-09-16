import 'dart:convert';
import 'dart:typed_data';
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
  showDialog(
    context: context,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<ProductsBloc>()),
        BlocProvider.value(value: context.read<SettingsBloc>()),
      ],
      child: _ProductDialog(item: item, initialCategory: initialCategory),
    ),
  );
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.item, this.initialCategory});
  final Item? item;
  final String? initialCategory;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final TextEditingController _name;
  late final TextEditingController _hsn;
  late final TextEditingController _code;
  late final TextEditingController _purchase;
  late final TextEditingController _sales;
  late final TextEditingController _stock;
  late final TextEditingController _unit;
  late final TextEditingController _low;

  late bool _isService;
  late String _selectedCat;
  String? _image;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.item;
    _name     = TextEditingController(text: p?.name          ?? '');
    _hsn      = TextEditingController(text: p?.hsn           ?? '');
    _code     = TextEditingController(text: p?.itemCode      ?? '');
    _purchase = TextEditingController(text: '${p?.purchasePrice ?? 0}');
    _sales    = TextEditingController(text: '${p?.salesPrice    ?? 0}');
    _stock    = TextEditingController(text: '${p?.currentStock  ?? 0}');
    _unit     = TextEditingController(text: p?.unit          ?? 'Pcs');
    _low      = TextEditingController(text: '${p?.lowStockLimit ?? 5}');
    _isService  = p?.isService ?? false;
    _image      = p?.image;

    final settingsState = context.read<SettingsBloc>().state;
    final categories = settingsState is SettingsLoaded ? settingsState.categories : ['General'];
    _selectedCat = p?.category ?? widget.initialCategory ?? 'General';
    if (!categories.contains(_selectedCat)) {
      _selectedCat = categories.isNotEmpty ? categories.first : 'General';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _hsn.dispose();
    _code.dispose();
    _purchase.dispose();
    _sales.dispose();
    _stock.dispose();
    _unit.dispose();
    _low.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1000,
    );
    if (f != null) {
      final bytes = await f.readAsBytes();
      setState(() => _image = base64Encode(bytes));
    }
  }

  Uint8List? _decodeImage(String? image) {
    final raw = image?.trim();
    if (raw == null || raw.isEmpty) return null;

    try {
      final payload = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  void _save() {
    if (_name.text.trim().isEmpty ||
        double.tryParse(_sales.text) == null ||
        double.tryParse(_purchase.text) == null ||
        double.tryParse(_stock.text) == null) {
      setState(() => _error = 'Please enter valid details and numeric values.');
      return;
    }

    final savedItem = Item(
      id: widget.item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name:          _name.text.trim(),
      hsn:           _hsn.text.trim(),
      itemCode:      _code.text.trim(),
      purchasePrice: double.parse(_purchase.text),
      salesPrice:    double.parse(_sales.text),
      currentStock:  double.parse(_stock.text),
      category:      _selectedCat,
      unit:          _unit.text.trim().isEmpty ? 'Pcs' : _unit.text.trim(),
      lowStockLimit: double.tryParse(_low.text) ?? 5,
      isService:     _isService,
      image:         _image,
    );

    context.read<ProductsBloc>().add(SaveProductRequested(savedItem));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = context.watch<SettingsBloc>().state;
    final categories = (settingsState is SettingsLoaded && settingsState.categories.isNotEmpty)
        ? settingsState.categories
        : ['General'];
    final isEdit = widget.item != null;
    final isNarrow = MediaQuery.sizeOf(context).width < 560;
    final imageBytes = _decodeImage(_image);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 560,
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
                      isEdit ? 'Edit Product' : 'Create New Product',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: categories.contains(_selectedCat) ? _selectedCat : categories.first,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCat = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    EmpiranTextField(
                      controller: _name,
                      label: 'Product Name',
                      hint: 'e.g. LED Downlight 15W',
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    if (isNarrow) ...[
                      EmpiranTextField(
                        controller: _code,
                        label: 'SKU / Barcode',
                        hint: 'Item code',
                      ),
                      const SizedBox(height: 12),
                      EmpiranTextField(
                        controller: _hsn,
                        label: 'HSN Code',
                        hint: 'e.g. 8539',
                      ),
                      const SizedBox(height: 12),
                      EmpiranTextField(
                        controller: _sales,
                        label: 'Selling Price (₹)',
                        hint: '0.00',
                        isNumber: true,
                        isDecimal: true,
                        isRequired: true,
                      ),
                      const SizedBox(height: 12),
                      EmpiranTextField(
                        controller: _purchase,
                        label: 'Purchase Cost (₹)',
                        hint: '0.00',
                      ),
                      const SizedBox(height: 12),
                      EmpiranTextField(
                        controller: _stock,
                        label: 'Current Stock',
                        hint: '0',
                        isNumber: true,
                        isDecimal: true,
                      ),
                      const SizedBox(height: 12),
                      EmpiranTextField(
                        controller: _unit,
                        label: 'Unit of Measure',
                        hint: 'Pcs, Mtr, Box, Kg',
                      ),
                      const SizedBox(height: 12),
                      EmpiranTextField(
                        controller: _low,
                        label: 'Low Stock Alert',
                        hint: '5',
                        isNumber: true,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: EmpiranTextField(
                              controller: _code,
                              label: 'SKU / Barcode',
                              hint: 'Item code',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EmpiranTextField(
                              controller: _hsn,
                              label: 'HSN Code',
                              hint: 'e.g. 8539',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: EmpiranTextField(
                              controller: _sales,
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
                              controller: _purchase,
                              label: 'Purchase Cost (₹)',
                              hint: '0.00',
                              isNumber: true,
                              isDecimal: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: EmpiranTextField(
                              controller: _stock,
                              label: 'Current Stock',
                              hint: '0',
                              isNumber: true,
                              isDecimal: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EmpiranTextField(
                              controller: _unit,
                              label: 'Unit of Measure',
                              hint: 'Pcs, Mtr, Box, Kg',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EmpiranTextField(
                              controller: _low,
                              label: 'Low Stock Alert',
                              hint: '5',
                              isNumber: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'This is a service (no inventory tracking)',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _isService,
                      onChanged: (v) => setState(() => _isService = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (imageBytes != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.medium),
                            child: Image.memory(
                              imageBytes,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        EmpiranButton(
                          label: _image == null ? 'Add Image' : 'Change Image',
                          icon: Icons.photo_library_outlined,
                          variant: EmpiranButtonVariant.outlined,
                          height: 40,
                          onPressed: _pickImage,
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
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
                        context.read<ProductsBloc>().add(DeleteProductRequested(widget.item!));
                        Navigator.pop(context);
                      },
                      child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  EmpiranButton(
                    label: 'Save Product',
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
