import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/outbox_repository.dart';
import '../../core/sync_service.dart';
import '../../models/models.dart';
import '../../state/data_providers.dart';

enum TransactionKind { revenue, expense }

/// Shown from the '+ Add Transaction' FAB (Section 25). Always writes to the
/// local outbox first and returns immediately -- SyncService pushes it to
/// the server in the background, whether online now or later. This is what
/// makes "record revenue/expense while offline" (Section 18) actually true
/// rather than just a UI that errors when there's no connection.
class AddTransactionSheet extends ConsumerStatefulWidget {
  final TransactionKind kind;
  const AddTransactionSheet({super.key, required this.kind});

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedBusinessUnitId;
  String? _selectedAccountId;
  String _category = 'other';
  bool _saving = false;

  final _revenueCategories = const ['rental', 'transportation', 'contract', 'monthly_rent', 'product_sales', 'gold_sales', 'other'];
  final _expenseCategories = const ['fuel', 'maintenance', 'spare_parts', 'salary', 'inventory_purchase', 'utility', 'other'];

  Future<void> _save() async {
  final amountText = _amountController.text.trim();
  final amount = double.tryParse(amountText);

  // Validate every required field before saving.
  if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select an account'),
      ),
    );
    return;
  }

  if (_selectedBusinessUnitId == null ||
      _selectedBusinessUnitId!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select a business unit'),
      ),
    );
    return;
  }

  if (amount == null || amount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter a valid amount greater than zero'),
      ),
    );
    return;
  }

  if (_saving) return;

  setState(() {
    _saving = true;
  });

  try {
    final payload = <String, dynamic>{
      'business_unit_id': _selectedBusinessUnitId,
      'account_id': _selectedAccountId,
      'category': _category,
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'amount': amount,
      'currency': 'ETB',
      'txn_date': DateTime.now().toIso8601String().split('T').first,
    };

    await OutboxRepository.instance.enqueue(
      entityType:
          widget.kind == TransactionKind.revenue ? 'revenue' : 'expense',
      payload: payload,
    );

    // Push immediately when online.
    // SyncService continues retrying when connectivity returns.
    await SyncService.instance.pushOutbox();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.kind == TransactionKind.revenue
              ? 'Revenue saved successfully'
              : 'Expense saved successfully',
        ),
      ),
    );

    Navigator.of(context).pop(true);
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to save transaction: $e'),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _saving = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final isRevenue = widget.kind == TransactionKind.revenue;
    final accountsAsync = ref.watch(accountsProvider);
    final categories = isRevenue ? _revenueCategories : _expenseCategories;

    return SafeArea(
  top: false,
  child: Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
    ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isRevenue ? 'Add Revenue' : 'Add Expense',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (ETB)', prefixIcon: Icon(Icons.payments_outlined)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ')))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
  loading: () => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: LinearProgressIndicator(),
  ),

  error: (err, _) => Text(
    'Unable to load accounts: $err',
    style: const TextStyle(color: Colors.red),
  ),

  data: (accounts) {
    if (accounts.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Account *',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.account_balance_outlined),
        ),
        child: Text(
          'No accounts available. Please create an account first.',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedAccountId,
      decoration: const InputDecoration(
        labelText: 'Account *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.account_balance_outlined),
      ),
      items: accounts.map((account) {
        return DropdownMenuItem<String>(
          value: account.id,
          child: Text(
            '${account.name} (${account.accountType})',
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedAccountId = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select an account';
        }
        return null;
      },
    );
  },
),
            const SizedBox(height: 12),
            _BusinessUnitPicker(
              selectedId: _selectedBusinessUnitId,
              onChanged: (id) => setState(() => _selectedBusinessUnitId = id),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Save ${isRevenue ? 'Revenue' : 'Expense'}'),
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

/// Minimal business-unit picker (vehicles for now; properties/shop/project
/// selection follows the same vehiclesProvider pattern once those list
/// providers are added in state/data_providers.dart).
class _BusinessUnitPicker extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  const _BusinessUnitPicker({required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    return vehiclesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (err, _) => const Text('Could not load business units'),
      data: (vehicles) => DropdownButtonFormField<String>(
        value: selectedId,
        decoration: const InputDecoration(labelText: 'Business Unit'),
        items: vehicles
            .map((v) => DropdownMenuItem(value: v.businessUnitId, child: Text(v.name)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
