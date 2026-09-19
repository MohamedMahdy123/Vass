import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/tryon_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Shows the try-on render (or its progress). Watches [TryOnState]; the
/// [pending] future is the in-flight run started by the try-on screen.
class TryOnResultScreen extends StatelessWidget {
  const TryOnResultScreen({
    super.key,
    required this.garmentLabel,
    required this.pending,
  });

  final String garmentLabel;
  final Future<void> pending;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final state = context.watch<TryOnState>();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: VessBackButton(onTap: () {
            context.read<TryOnState>().clearResult();
            Navigator.of(context).maybePop();
          }),
        ),
        title: Text('Your try-on', style: serif(context, 22)),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              Expanded(child: _body(context, state)),
              if (state.hasResult) _previewNote(context),
              const SizedBox(height: 16),
              if (state.hasResult) _actions(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, TryOnState state) {
    final t = context.vess;

    if (state.running) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30, height: 30,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: t.accent),
            ),
            const SizedBox(height: 18),
            Text('Rendering $garmentLabel on you…',
                style: TextStyle(fontFamily: kSans, fontSize: 14, color: t.ink2)),
            const SizedBox(height: 6),
            Text('This can take a minute or two on the free engine',
                style: TextStyle(fontFamily: kSans, fontSize: 12, color: t.ink3)),
          ],
        ),
      );
    }

    final result = state.result;
    if (result == null || result.resultBytes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty, size: 34, color: t.ink3),
              const SizedBox(height: 16),
              Text(
                state.error ?? 'Something went wrong. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: kSans, fontSize: 14, height: 1.5, color: t.ink2),
              ),
              const SizedBox(height: 20),
              AccentButton(
                label: 'Back to garments',
                onTap: () {
                  context.read<TryOnState>().clearResult();
                  Navigator.of(context).maybePop();
                },
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.memory(result.resultBytes!, fit: BoxFit.cover, width: double.infinity),
    );
  }

  /// An honest caveat. Shoppers distrust try-on renders precisely because they
  /// assume they flatter, so Vess says plainly what the preview is — a styling
  /// look, not a fit guarantee — and turns that honesty into a trust signal.
  Widget _previewNote(BuildContext context) {
    final t = context.vess;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: t.ink3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This is a styling preview — it shows how the look reads, not the '
              'fit. Check your usual size before buying.',
              style: TextStyle(
                  fontFamily: kSans, fontSize: 12, height: 1.45, color: t.ink3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, TryOnState state) {
    final t = context.vess;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  context.read<TryOnState>().clearResult();
                  Navigator.of(context).maybePop();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  side: BorderSide(color: t.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Try another',
                    style: TextStyle(
                        fontFamily: kSans, fontSize: 14, fontWeight: FontWeight.w600, color: t.ink2)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AccentButton(
                label: 'Done',
                expand: true,
                trailing: Icons.check,
                onTap: () {
                  context.read<TryOnState>().clearResult();
                  Navigator.of(context).maybePop();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
