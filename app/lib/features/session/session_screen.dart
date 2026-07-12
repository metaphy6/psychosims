import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psychemas/psychemas.dart';

import '../../shared/l10n.dart';
import 'session_controller.dart';

/// Phase 1 minimal session screen: structured action selector, streaming
/// dialogue render, and cancel control. No free-text prompt box.
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SessionController>();
    const l10n = L10n();

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.caseTitle())),
      ),
      body: SafeArea(
        child: Obx(() {
          switch (controller.status.value) {
            case SessionStatus.loading:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(l10n.manifestPresentation('session.loading')),
                  ],
                ),
              );
            case SessionStatus.error:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            case SessionStatus.ready:
            case SessionStatus.generating:
              return _SessionBody(controller: controller, l10n: l10n);
          }
        }),
      ),
    );
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({required this.controller, required this.l10n});

  final SessionController controller;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Obx(() {
            if (controller.displayTurns.isEmpty) {
              return Center(
                child: Text(l10n.manifestPresentation('session.empty_turns')),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: controller.displayTurns.length,
              itemBuilder: (context, index) {
                final turn = controller.displayTurns[index];
                return _TurnBubble(turn: turn);
              },
            );
          }),
        ),
        const Divider(height: 1),
        Obx(() {
          final actions = controller.availableActions();
          return _ActionPanel(
            actions: actions,
            locked: controller.isActionLocked.value,
            onAction: controller.submitAction,
            onCancel: controller.cancelTurn,
          );
        }),
      ],
    );
  }
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn});

  final DisplayTurn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = turn.isPlayer
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.secondaryContainer;
    final alignment =
        turn.isPlayer ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Semantics(
              label: turn.isPlayer ? 'Player action' : 'Patient response',
              child: Text(
                turn.text.isEmpty && turn.isStreaming ? '…' : turn.text,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.actions,
    required this.locked,
    required this.onAction,
    required this.onCancel,
  });

  final List<InteractionPattern> actions;
  final bool locked;
  final void Function(InteractionPattern) onAction;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    const l10n = L10n();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.manifestPresentation('session.actions_label'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in actions)
                ActionChip(
                  label: Text(action.name),
                  onPressed: locked ? null : () => onAction(action),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (locked)
            ElevatedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.stop),
              label: Text(l10n.manifestPresentation('session.cancel_button')),
            ),
        ],
      ),
    );
  }
}
