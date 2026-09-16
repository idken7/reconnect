import 'package:flutter/material.dart';

/// The app's primary button: a themed [FilledButton], on every platform.
class AdaptiveFilledButton extends StatelessWidget {
  const AdaptiveFilledButton({
    super.key,
    required this.onPressed,
    required Widget child,
    this.compact = false,
  })  : _child = child,
        _icon = null,
        _label = null;

  const AdaptiveFilledButton.icon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.compact = false,
  })  : _icon = icon,
        _label = label,
        _child = null;

  final VoidCallback? onPressed;
  final bool compact;
  final Widget? _child;
  final Widget? _icon;
  final Widget? _label;

  @override
  Widget build(BuildContext context) {
    final style = compact
        ? FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          )
        : null;
    return _icon != null
        ? FilledButton.icon(onPressed: onPressed, icon: _icon, label: _label!, style: style)
        : FilledButton(onPressed: onPressed, style: style, child: _child);
  }
}

/// The app's secondary button: a themed [OutlinedButton], on every platform.
class AdaptiveOutlinedButton extends StatelessWidget {
  const AdaptiveOutlinedButton({
    super.key,
    required this.onPressed,
    required Widget child,
    this.compact = false,
  })  : _child = child,
        _icon = null,
        _label = null;

  const AdaptiveOutlinedButton.icon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.compact = false,
  })  : _icon = icon,
        _label = label,
        _child = null;

  final VoidCallback? onPressed;
  final bool compact;
  final Widget? _child;
  final Widget? _icon;
  final Widget? _label;

  @override
  Widget build(BuildContext context) {
    final style = compact
        ? OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          )
        : null;
    return _icon != null
        ? OutlinedButton.icon(onPressed: onPressed, icon: _icon, label: _label!, style: style)
        : OutlinedButton(onPressed: onPressed, style: style, child: _child);
  }
}
