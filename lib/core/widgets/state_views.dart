import 'package:flutter/material.dart';

import '../../theme/ogera_colors.dart';
import '../network/api_client.dart';

/// Every list in the app has an explicit loading, empty, and error state. These
/// three widgets are the only approved way to render them.

class LoadingListView extends StatelessWidget {
  const LoadingListView({super.key, this.itemCount = 6, this.itemHeight = 96});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(OgeraSpacing.screen),
      physics: const NeverScrollableScrollPhysics(),
      // Nested inside the Home dashboard's ListView, so it must size to its
      // children rather than demand the viewport's (unbounded) height.
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: OgeraSpacing.gap),
      itemBuilder: (_, _) => ShimmerBox(height: itemHeight),
    );
  }
}

/// A quiet pulse rather than a spinner: it keeps the page layout stable while
/// data arrives, so content does not jump into place.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = OgeraSpacing.cardRadius,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(
              OgeraColors.blue.withValues(alpha: 0.08),
              OgeraColors.blue.withValues(alpha: 0.15),
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// Centred spinner with a short label, for screens whose content is one
/// unit (a report, a filtered list) rather than a stack of repeating rows.
class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: OgeraColors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: OgeraColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: const BoxDecoration(
                color: OgeraColors.blueSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: OgeraColors.blue),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: OgeraColors.muted, height: 1.45),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.onRetry,
    this.kind = FailureKind.server,
  });

  final String message;
  final VoidCallback? onRetry;
  final FailureKind kind;

  /// A permission problem is not retryable, so no "Try again" is offered.
  bool get _canRetry => onRetry != null && kind != FailureKind.forbidden;

  ({IconData icon, String title, bool danger}) get _presentation {
    return switch (kind) {
      FailureKind.offline => (
        icon: Icons.wifi_off_rounded,
        title: 'No connection',
        danger: false,
      ),
      FailureKind.unauthorized => (
        icon: Icons.lock_outline_rounded,
        title: 'Session ended',
        danger: false,
      ),
      FailureKind.forbidden => (
        icon: Icons.no_accounts_rounded,
        title: 'No access',
        danger: false,
      ),
      FailureKind.notFound => (
        icon: Icons.search_off_rounded,
        title: 'Not found',
        danger: false,
      ),
      FailureKind.server => (
        icon: Icons.cloud_off_rounded,
        title: 'Something went wrong',
        danger: true,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = _presentation;
    final tint = style.danger ? OgeraColors.danger : OgeraColors.muted;
    final wash = style.danger ? OgeraColors.dangerSoft : OgeraColors.blueSoft;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(color: wash, shape: BoxShape.circle),
              child: Icon(style.icon, size: 38, color: tint),
            ),
            const SizedBox(height: 20),
            Text(style.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: OgeraColors.muted, height: 1.45),
            ),
            if (_canRetry) ...[
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A failure that should not take the screen over: the data already on screen
/// stays visible and the banner offers a retry. Used when a refresh or a later
/// page fails after the first load succeeded.
class InlineErrorBanner extends StatelessWidget {
  const InlineErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
    this.kind = FailureKind.server,
  });

  final String message;
  final VoidCallback onRetry;
  final FailureKind kind;

  @override
  Widget build(BuildContext context) {
    final offline = kind == FailureKind.offline;
    final tint = offline ? OgeraColors.warning : OgeraColors.danger;
    final wash = offline ? OgeraColors.warningSoft : OgeraColors.dangerSoft;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
            size: 20,
            color: tint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              offline ? "You're offline. Showing the last loaded data." : message,
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Fills the remaining viewport so an empty or error state is vertically
/// centred inside a `RefreshIndicator`, which needs a scrollable child.
class RefreshableMessage extends StatelessWidget {
  const RefreshableMessage({super.key, required this.child, this.onRefresh});

  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}
