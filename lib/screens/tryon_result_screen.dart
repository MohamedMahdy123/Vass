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
          padding: const EdgeInsets.all(24),
          child: Text(
            state.error ?? 'Something went wrong. Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kSans, fontSize: 14, color: t.ink2),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(result.resultBytes!, fit: BoxFit.cover),
          // Honest badge: the demo stand-in isn't a real render.
          if (result.model == 'demo')
            Positioned(
              left: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('DEMO PREVIEW',
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.white,
                    )),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, TryOnState state) {
    final t = context.vess;
    final isDemo = state.result?.model == 'demo';
    return Column(
      children: [
        if (isDemo)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'This is a demo stand-in. Add the try-on engine key to get a real render.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: kSans, fontSize: 12, color: t.ink3),
            ),
          ),
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
