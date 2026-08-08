import 'package:flutter/material.dart';

/// A ScaffoldMessenger that outlives individual screens.
///
/// Why this is necessary rather than convenient: paying for an order ends in
/// `_showBalanceMessageDialog`, which calls
/// `Navigator.pushAndRemoveUntil(..., (route) => false)` — the tender screen and
/// its BuildContext are destroyed the moment the cashier taps OK. Receipt
/// printing now runs in the background and routinely finishes *after* that, so
/// it has no context of its own to report through. This key lives on
/// MaterialApp, above the Navigator, so it survives every route swap.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Shows [banner], replacing any banner already on screen.
///
/// The replace is deliberate. ScaffoldMessenger *queues* banners by default, so
/// during a printer outage six failed payments would leave six banners to
/// dismiss one after another. Only the newest is actionable, so only the newest
/// is shown.
///
/// No-ops when there is no app tree — unit tests and headless startup must not
/// have to care that this exists.
void showGlobalBanner(MaterialBanner banner) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.clearMaterialBanners();
  messenger.showMaterialBanner(banner);
}

/// Dismisses the current banner, if any. Safe to call when none is showing.
void hideGlobalBanner() {
  rootScaffoldMessengerKey.currentState?.clearMaterialBanners();
}
