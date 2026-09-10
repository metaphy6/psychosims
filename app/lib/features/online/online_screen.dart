import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import '../../app/app_routes.dart';
import '../../shared/api_client.dart';
import '../../shared/auth_service.dart';
import '../../shared/browser_auth_service.dart';
import '../../shared/l10n.dart';
import '../../shared/model_cache.dart';
import '../../shared/online_session_service.dart';

class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key});
  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen>
    with WidgetsBindingObserver {
  late final OnlineSessionService _online;
  late final BrowserAuthService _browser;
  late final AuthService _auth;
  bool _busy = false;
  String? _error;
  Timer? _reconnect;
  @override
  void initState() {
    super.initState();
    _online = Get.find();
    _browser = Get.find();
    _auth = Get.find();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_run(() async {
      await _auth.flushLogouts();
      await _browser.resumeExchange();
      await _online.refreshStatus();
      if (_online.status.value.accountId != null) await _online.sync();
    }));
    // A bounded outbox retry while this screen is visible also covers transports
    // which regain connectivity without emitting an OS lifecycle event.
    _reconnect = Timer.periodic(
        Duration(milliseconds: _online.network.maxRetryAfterMillis), (_) {
      if (!_busy && _online.status.value.pending > 0) {
        unawaited(_run(_online.sync));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) {
      unawaited(_run(_online.sync));
    }
  }

  @override
  void dispose() {
    _reconnect?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) _error = L10n.onlineError(error.kind);
    } catch (_) {
      if (mounted) _error = L10n.onlineError('storage_unavailable');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn(String provider) => _run(() async {
        await _browser.signIn(provider);
        await _online.sync();
      });
  Future<void> _start() => _run(() async {
        final config = Get.find<ConfigProvider>().config;
        await Get.find<ModelCache>().requireModelPath();
        final bytes = await rootBundle.load(config.content.bundledManifestPath);
        final manifest = ManifestLoader(
                limits: ManifestLoaderLimits(
                    maxBytes: config.content.maxManifestBytes,
                    maxMapDepth: config.content.maxManifestDepth),
                catalog: const L10n())
            .load(bytes.buffer.asUint8List());
        await _online.sync();
        final owned = (_online.status.value.profile?['owned_card_ids'] as List?)
                ?.cast<String>()
                .toSet() ??
            <String>{};
        final cards = manifest.resolvedCards
            .map((card) => card.id)
            .where(owned.contains)
            .take(config.balance.activeCardSlots)
            .toList();
        if (cards.isEmpty) throw StateError('No owned actions are available');
        final context = await _online.start(manifest: manifest, cardIds: cards);
        if (!mounted) return;
        await Get.toNamed(AppRoutes.session,
            arguments: {'online_context': context});
        await _online.sync();
      });
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(L10n.onlineTitle)),
        body: SafeArea(
            child: ValueListenableBuilder<OnlineSyncStatus>(
                valueListenable: _online.status,
                builder: (context, state, _) => ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(L10n.onlineDescription,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 16),
                        if (_busy || state.syncing)
                          const LinearProgressIndicator(),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        if (state.accountId == null) ...[
                          const SizedBox(height: 16),
                          Text(_browser.configured
                              ? L10n.onlineSignedOut
                              : L10n.onlineNotConfigured),
                          const SizedBox(height: 16),
                          FilledButton(
                              onPressed: _busy || !_browser.configured
                                  ? null
                                  : () => _signIn('google'),
                              child: const Text(L10n.onlineGoogle)),
                          OutlinedButton(
                              onPressed: _busy || !_browser.configured
                                  ? null
                                  : () => _signIn('apple'),
                              child: const Text(L10n.onlineApple)),
                        ] else ...[
                          const SizedBox(height: 16),
                          if (state.profile != null)
                            Text(
                                L10n.onlineProfile(
                                    state.profile!['level'] as int? ?? 0,
                                    state.profile!['xp'] as int? ?? 0),
                                style: Theme.of(context).textTheme.titleLarge),
                          Text(state.stale
                              ? L10n.onlineProfileStale
                              : L10n.onlineProfileCurrent),
                          const SizedBox(height: 16),
                          const Text(L10n.onlineCoverage),
                          const SizedBox(height: 16),
                          FilledButton(
                              onPressed: _busy ? null : _start,
                              child: const Text(L10n.onlineStart)),
                          OutlinedButton(
                              onPressed:
                                  _busy ? null : () => _run(_online.sync),
                              child: const Text(L10n.onlineSync)),
                          Text(L10n.onlinePending(state.pending)),
                          if (state.errorKind != null)
                            Text(L10n.onlineError(state.errorKind!)),
                          for (final verdict
                              in state.verdicts.reversed.take(20))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(verdict.status == 'accepted'
                                  ? Icons.cloud_done_outlined
                                  : Icons.error_outline),
                              title: Text(L10n.onlineVerdict(verdict.status,
                                  rewardStatus: verdict.rewardStatus)),
                              subtitle: Text(L10n.onlineRewardDetail(verdict)),
                            ),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                        await _online.discardExpired();
                                        await _online.refreshStatus();
                                      }),
                              child: const Text(L10n.onlineDiscardExpired)),
                          TextButton(
                              onPressed: _busy || state.pending > 0
                                  ? null
                                  : () => _run(_online.recoverDeviceKey),
                              child: const Text(L10n.onlineRecoverKey)),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                        await _auth.logout();
                                        await _online.refreshStatus();
                                      }),
                              child: const Text(L10n.onlineSignOut)),
                        ],
                      ],
                    ))),
      );
}
