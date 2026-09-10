import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/ogera_colors.dart';
import '../utils/formatters.dart';

/// The shared visual kit. Anything that appears on more than one screen lives
/// here so the app reads as one product rather than eight separate modules.

/// A white rounded panel with the standard hairline border and soft shadow.
class OgeraCard extends StatelessWidget {
  const OgeraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accent,
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// When set, draws a 4 px identity stripe down the leading edge — used for
  /// staff colours and stage colours.
  final Color? accent;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: OgeraColors.surface,
        borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
        border: Border.all(color: OgeraColors.line),
        boxShadow: OgeraColors.lowShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: accent == null
              ? content
              // The stripe has no height of its own and relies on `stretch`,
              // which is a tight constraint — unbounded inside a list. Stack
              // sizes to `content` and the stripe spans that measured height.
              : Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: content,
                    ),
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: ColoredBox(color: accent!),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

enum StatusTone { neutral, info, success, warning, danger, brand }

/// Status is never carried by colour alone — every chip also carries its label,
/// and optionally an icon.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    this.color,
    this.dense = false,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  /// Overrides the tone, for staff identity colours.
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? _foreground(tone);
    final background = color?.withValues(alpha: 0.12) ?? _background(tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(OgeraSpacing.chipRadius),
        border: Border.all(color: foreground.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  static Color _foreground(StatusTone tone) => switch (tone) {
    StatusTone.neutral => OgeraColors.muted,
    StatusTone.info => OgeraColors.info,
    StatusTone.success => OgeraColors.success,
    StatusTone.warning => OgeraColors.warning,
    StatusTone.danger => OgeraColors.danger,
    StatusTone.brand => OgeraColors.blue,
  };

  static Color _background(StatusTone tone) => switch (tone) {
    StatusTone.neutral => OgeraColors.canvas,
    StatusTone.info => const Color(0xFFE5F3FB),
    StatusTone.success => OgeraColors.successSoft,
    StatusTone.warning => OgeraColors.warningSoft,
    StatusTone.danger => OgeraColors.dangerSoft,
    StatusTone.brand => OgeraColors.blueSoft,
  };
}

/// Monogram avatar. [color] carries staff identity where one applies.
class OgeraAvatar extends StatelessWidget {
  const OgeraAvatar({
    super.key,
    required this.name,
    this.phone,
    this.color,
    this.size = 44,
  });

  final String? name;
  final String? phone;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? OgeraColors.blue;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        shape: BoxShape.circle,
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Text(
        initialsOf(name, fallback: phone),
        style: TextStyle(
          color: tint,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// The round call / WhatsApp / directions buttons on list rows and detail
/// headers. Sized to the 44 px minimum touch target.
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = OgeraColors.blue,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: OgeraSpacing.touchTarget,
          height: OgeraSpacing.touchTarget,
          child: Material(
            color: color.withValues(alpha: onPressed == null ? 0.05 : 0.11),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Icon(
                icon,
                size: 20,
                color: onPressed == null ? OgeraColors.muted : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section heading used inside detail screens and forms.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.icon});

  final String title;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: OgeraColors.muted),
            const SizedBox(width: 7),
          ],
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: OgeraColors.muted,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Label + value line used throughout the detail screens. Long values wrap
/// rather than truncate, because addresses matter.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final Color? valueColor;
  final VoidCallback? onTap;

  /// Lets a section hide itself when every row inside it is empty.
  bool get hasValue => (value ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 16, color: OgeraColors.muted),
              ),
              const SizedBox(width: 10),
            ],
            SizedBox(
              width: 108,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: OgeraColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? OgeraColors.ink,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: OgeraColors.muted,
              ),
          ],
        ),
      ),
    );
  }
}

/// Search field with a debounce-friendly controller and a clear button.
class OgeraSearchField extends StatelessWidget {
  const OgeraSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 14.5),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 21,
              color: OgeraColors.muted,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 19),
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                      onClear?.call();
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        );
      },
    );
  }
}

/// Horizontal scroller of selectable filter chips.
class FilterChipBar<T> extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    this.countOf,
    this.padding = const EdgeInsets.symmetric(horizontal: OgeraSpacing.screen),
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final int? Function(T value)? countOf;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = values[index];
          final isSelected = value == selected;
          final count = countOf?.call(value);
          return GestureDetector(
            onTap: () => onSelected(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? OgeraColors.blue : OgeraColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? OgeraColors.blue : OgeraColors.line,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    labelOf(value),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : OgeraColors.ink,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.22)
                            : OgeraColors.canvas,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : OgeraColors.muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Confirmation for destructive actions, per the design rules.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: destructive
                    ? OgeraColors.dangerSoft
                    : OgeraColors.blueSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                destructive
                    ? Icons.delete_outline_rounded
                    : Icons.help_outline_rounded,
                color: destructive ? OgeraColors.danger : OgeraColors.blue,
                size: 27,
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 22),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: OgeraColors.danger)
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

void showToast(BuildContext context, String message, {bool isError = false}) {
  if (!context.mounted) return;
  HapticFeedback.lightImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFF86EFAC),
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
