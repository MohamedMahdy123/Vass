import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/closet_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// "Everything you have worn" — every closet piece with its last-worn note.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final items = context.watch<AppState>().closet;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: VessBackButton(),
        ),
        title: Text('History', style: serif(context, 22)),
        centerTitle: true,
      ),
      body: items.isEmpty
          ? Center(
              child: Text('Nothing worn yet',
                  style: TextStyle(fontFamily: kSans, fontSize: 14, color: t.ink3)),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _HistoryRow(item: items[i]),
            ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});
  final ClosetItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(width: 48, height: 60, child: Swatch(item: item, radius: 12)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: kSerif, fontSize: 16, color: t.ink)),
                const SizedBox(height: 3),
                Text('Last worn · ${item.worn}',
                    style: TextStyle(fontFamily: kSans, fontSize: 12.5, color: t.ink3)),
              ],
            ),
          ),
          Icon(Icons.history, size: 18, color: t.ink3),
        ],
      ),
    );
  }
}
