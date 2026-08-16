import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';

/// Formats a number as "ETB 125,500.00" per Section 23.
String formatCurrency(double amount, {String currency = 'ETB'}) {
  final formatter = NumberFormat.currency(symbol: '$currency ', decimalDigits: 2);
  return formatter.format(amount);
}

class SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final bool emphasizeSign;

  const SummaryCard({
    super.key,
    required this.label,
    required this.amount,
    required this.icon,
    this.emphasizeSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = emphasizeSign ? (amount >= 0 ? AppTheme.profitColor : AppTheme.lossColor) : Colors.black87;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              formatCurrency(amount),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
