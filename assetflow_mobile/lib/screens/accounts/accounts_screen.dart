import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/data_providers.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/app_back_button.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  IconData _iconFor(String type) {
    switch (type) {
      case 'cash':
        return Icons.payments_outlined;
      case 'bank':
        return Icons.account_balance_outlined;
      case 'mobile_money':
        return Icons.phone_iphone_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Transfer between accounts',
            onPressed: () => _showTransferDialog(context, ref),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(child: Text('Could not load accounts')),
        data: (accounts) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(accountsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Icon(_iconFor(account.accountType), color: AppTheme.primary),
                  ),
                  title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(account.accountType.replaceAll('_', ' ')),
                  trailing: Text(
                    formatCurrency(account.currentBalance, currency: account.currency),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showTransferDialog(BuildContext context, WidgetRef ref) async {
    final accounts = await ref.read(accountsProvider.future);
    if (accounts.length < 2) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Need at least two accounts to transfer between')));
      }
      return;
    }

    String? fromId = accounts.first.id;
    String? toId = accounts[1].id;
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Transfer Between Accounts'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: fromId,
                decoration: const InputDecoration(labelText: 'From'),
                items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setState(() => fromId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: toId,
                decoration: const InputDecoration(labelText: 'To'),
                items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setState(() => toId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (ETB)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (fromId == null || toId == null || fromId == toId) return;
                try {
                  await ApiClient.instance.dio.post('/accounts/transfer', data: {
                    'from_account_id': fromId,
                    'to_account_id': toId,
                    'amount': double.tryParse(amountController.text) ?? 0,
                    'transfer_date': DateTime.now().toIso8601String().split('T').first,
                    'idempotency_key': const Uuid().v4(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ref.invalidate(accountsProvider);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transfer failed'), backgroundColor: AppTheme.danger),
                    );
                  }
                }
              },
              child: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );
  }
}
