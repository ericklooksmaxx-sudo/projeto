import 'package:material_ui/material_ui.dart';

import '../kz_components.dart';
import '../kz_motion.dart';
import '../kz_surface.dart';
import '../kz_text.dart';
import '../kz_tokens.dart';
import 'kz_site.dart';
import 'pass_service.dart';

/// The gate, as the app shows it.
///
/// The steps themselves run on the site (kyzendlc.xyz/gate) — this page states
/// what the pass is, opens it in the browser, and watches for the pass landing
/// back on the device.
class KzGatePage extends StatefulWidget {
  final String? dlcId;
  final String? packTitle;

  const KzGatePage({super.key, this.dlcId, this.packTitle});

  static Future<void> open(
    BuildContext context, {
    String? dlcId,
    String? packTitle,
  }) {
    return Navigator.of(context).push(
      KzPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => KzGatePage(dlcId: dlcId, packTitle: packTitle),
      ),
    );
  }

  @override
  State<KzGatePage> createState() => _KzGatePageState();
}

class _KzGatePageState extends State<KzGatePage> with WidgetsBindingObserver {
  final KzPass _pass = KzPass.instance;
  bool _sentToBrowser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pass.clearError();
    _pass.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // back from the browser: the pass may already be on the device
    if (state == AppLifecycleState.resumed && _sentToBrowser) {
      _pass.refresh();
    }
  }

  Future<void> _start() async {
    final String? error = await _pass.openGate(dlcId: widget.dlcId);
    if (!mounted) return;
    if (error == null) setState(() => _sentToBrowser = true);
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: KzBackdrop(
        child: AnimatedBuilder(
          animation: _pass,
          builder: (context, _) {
            final bool on = _pass.active;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                safe.top + 12,
                16,
                safe.bottom + 28,
              ),
              children: [
                Row(
                  children: [
                    const KzBrandWord(size: 22),
                    const Spacer(),
                    KzIconButton(
                      icon: Icons.close,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                KzReveal(
                  child: KzPageTitle(on ? 'Pass running' : 'Unlock downloads'),
                ),
                const SizedBox(height: 14),
                KzReveal(
                  delay: const Duration(milliseconds: 60),
                  child: Text(
                    on
                        ? 'Every download is open for the next ${_pass.remainingLabel}. Nothing else to do.'
                        : '3 quick sponsor visits unlock every download for 24 hours. Free, no sign-up.',
                    style: KzType.lead,
                  ),
                ),
                if (widget.packTitle != null) ...[
                  const SizedBox(height: 18),
                  KzReveal(
                    delay: const Duration(milliseconds: 90),
                    child: KzPanel(
                      radius: KzRadius.rCtl,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 20,
                            color: KzColors.p300,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'After the pass, you come back to',
                                  style: KzType.meta,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.packTitle!,
                                  style: KzType.label.copyWith(fontSize: 15),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                KzReveal(
                  delay: const Duration(milliseconds: 120),
                  child: on ? _runningPanel() : _stepsPanel(),
                ),
                if (_pass.lastError != null) ...[
                  const SizedBox(height: 16),
                  KzAlert(
                    title: 'The pass did not start',
                    body: _pass.lastError,
                    icon: Icons.error_outline,
                    tone: KzAlertTone.bad,
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'The gate runs on ${KzSite.host}. The app never asks for an '
                  'account, and the pass is tied to this device.',
                  style: KzType.meta,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _runningPanel() {
    return KzGlass(
      radius: KzRadius.rPanel,
      rim: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          KzAlert(
            title: 'Downloads unlocked',
            body: '${_pass.remainingLabel} left on this device.',
            icon: Icons.verified_outlined,
            tone: KzAlertTone.good,
          ),
          const SizedBox(height: 18),
          KzButton(
            label: 'Back to the packs',
            kind: KzButtonKind.light,
            block: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 10),
          KzButton(
            label: 'Check again',
            kind: KzButtonKind.ghost,
            size: KzButtonSize.sm,
            block: true,
            loading: _pass.checking,
            onPressed: () => _pass.refresh(quiet: false),
          ),
        ],
      ),
    );
  }

  Widget _stepsPanel() {
    const List<String> steps = <String>[
      'Sponsor 1 — open it and stay 10 seconds',
      'Sponsor 2 — same again',
      'Sponsor 3 — last one',
      'Human check — one tap',
    ];

    return KzGlass(
      radius: KzRadius.rPanel,
      rim: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepRow(index: i + 1, label: steps[i]),
            if (i != steps.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          KzButton(
            label: _sentToBrowser ? 'Open the pass again' : 'Open the pass',
            icon: Icons.open_in_new,
            block: true,
            loading: _pass.opening,
            onPressed: _pass.busy ? null : _start,
          ),
          if (_sentToBrowser) ...[
            const SizedBox(height: 12),
            Text(
              'Finish the steps in your browser. When it is done you come back '
              'here on your own — if not, tap below.',
              style: KzType.meta,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            KzButton(
              label: 'I finished — check the pass',
              kind: KzButtonKind.secondary,
              size: KzButtonSize.sm,
              block: true,
              loading: _pass.checking || _pass.claiming,
              onPressed: () => _pass.refresh(quiet: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String label;

  const _StepRow({required this.index, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x336F0ECF),
            borderRadius: KzRadius.rPill,
            border: Border.all(color: const Color(0x57BB92FF)),
          ),
          child: Text(
            '$index',
            style: KzType.tiny.copyWith(color: KzColors.p100),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: KzType.body.copyWith(color: KzColors.ink2)),
        ),
      ],
    );
  }
}
