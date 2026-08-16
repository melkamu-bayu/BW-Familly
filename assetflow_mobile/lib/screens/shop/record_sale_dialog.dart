import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../state/data_providers.dart';

/// Single-line-item sale entry, reachable from the Shop screen. Deliberately
/// scoped to one product per sale for now -- multi-line POS (several
/// products in one invoice) would extend `items` into a growable list here
/// without changing the backend contract, which already accepts a list.
class RecordSaleDialog extends ConsumerStatefulWidget {
  const RecordSaleDialog({super.key});

  @override
  ConsumerState<RecordSaleDialog> createState() => _RecordSaleDialogState();
}

class _RecordSaleDialogState extends ConsumerState<RecordSaleDialog> {
  String? _productId;
  String? _customerId;
  String? _accountId;
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_productId == null || _accountId == null || _quantityController.text.isEmpty) {
      setState(() => _error = 'Product, account, and quantity are required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final products = await ref.read(shopProductsProvider.future);
    final product = products.firstWhere((p) => p.id == _productId);
    final unitPrice = double.tryParse(_unitPriceController.text) ?? product.sellingPrice ?? 0;

    try {
      await ApiClient.instance.dio.post('/shop/sales', data: {
        'invoice_number': 'SALE-${DateTime.now().millisecondsSinceEpoch}',
        'customer_id': _customerId,
        'account_id': _accountId,
        'payment_status': 'paid',
        'payment_method': 'cash',
        'discount': 0,
        'sale_date': DateTime.now().toIso8601String().split('T').first,
        'idempotency_key': const Uuid().v4(),
        'items': [
          {
            'product_id': _productId,
            'quantity': double.tryParse(_quantityController.text) ?? 1,
            'unit_price': unitPrice,
          }
        ],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Could not record sale — check stock availability');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(shopProductsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final customersAsync = ref.watch(customersProvider);

    return AlertDialog(
      title: const Text('Record Sale'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            productsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => const Text('Could not load products'),
              data: (products) => DropdownButtonFormField<String>(
                value: _productId,
                decoration: const InputDecoration(labelText: 'Product'),
                items: products
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name} (${p.currentQuantity} ${p.unit} in stock)'),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _productId = v;
                    final product = products.firstWhere((p) => p.id == v);
                    _unitPriceController.text = product.sellingPrice?.toStringAsFixed(2) ?? '';
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unitPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Unit Price (ETB)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            customersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => const Text('Could not load customers'),
              data: (customers) => DropdownButtonFormField<String>(
                value: _customerId,
                decoration: const InputDecoration(labelText: 'Customer (optional)'),
                items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _customerId = v),
              ),
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => const Text('Could not load accounts'),
              data: (accounts) => DropdownButtonFormField<String>(
                value: _accountId,
                decoration: const InputDecoration(labelText: 'Deposit to Account'),
                items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setState(() => _accountId = v),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Record Sale'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }
}
