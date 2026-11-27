import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../animation/app_curves.dart';
import '../theme/app_typography.dart';
import '../theme/glass_tokens.dart';
import 'glass_container.dart';

/// Glass text field (UI spec §6): rounded-rect (16px), black text, placeholder
/// at black 40%, and a soft white glow (white 30%, blur 12) that animates in
/// over 200ms when focused.
class GlassInput extends StatefulWidget {
  const GlassInput({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.label,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.maxLength,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.autofillHints,
    this.errorText,
    this.textAlignVertical,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? label;
  final IconData? prefixIcon;

  /// Extra widget pinned to the right of the field (e.g. a trailing action).
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool enableSuggestions;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final TextAlignVertical? textAlignVertical;
  final bool autofocus;

  @override
  State<GlassInput> createState() => _GlassInputState();
}

class _GlassInputState extends State<GlassInput> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late bool _obscured = widget.obscureText;

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final focused = _focusNode.hasFocus;
    final singleLine = widget.maxLines == 1;

    final field = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autocorrect: widget.autocorrect && !_obscured,
      enableSuggestions: widget.enableSuggestions && !_obscured,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      autofillHints: widget.autofillHints,
      textAlignVertical:
          widget.textAlignVertical ??
          (singleLine ? TextAlignVertical.center : TextAlignVertical.top),
      cursorColor: t.textPrimary,
      cursorWidth: 1.5,
      style: t.onGlass(AppType.body()),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
        counterText: '',
        hintText: widget.hint,
        hintStyle: t.onGlassMuted(AppType.body()),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpace.xs),
            child: Text(widget.label!, style: t.onGlass(AppType.micro())),
          ),
        AnimatedContainer(
          duration: AppMotion.focusGlow,
          curve: AppMotion.focusCurve,
          decoration: BoxDecoration(
            borderRadius: AppSpace.fieldRadius,
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: const Color(0xFF6D5DF6).withValues(alpha: 0.18),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: GlassContainer(
            borderRadius: 16,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: singleLine ? 14 : AppSpace.md,
            ),
            borderStrongColor: focused
                ? const Color(0xFF6D5DF6)
                : t.borderStrong,
            borderWidth: focused ? 1.25 : 1,
            showShadow: false,
            child: Row(
              crossAxisAlignment: singleLine
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                if (widget.prefixIcon != null) ...[
                  Padding(
                    padding: singleLine
                        ? EdgeInsets.zero
                        : const EdgeInsets.only(top: 2),
                    child: Icon(
                      widget.prefixIcon,
                      size: 18,
                      color: t.placeholder,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                ],
                Expanded(child: field),
                if (_obscureToggle(t) != null) ...[
                  const SizedBox(width: AppSpace.sm),
                  _obscureToggle(t)!,
                ],
                if (widget.suffix != null) ...[
                  const SizedBox(width: AppSpace.sm),
                  widget.suffix!,
                ],
              ],
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: AppSpace.xs),
            child: Text(
              widget.errorText!,
              style: AppType.caption(color: const Color(0xFFFF3B30)),
            ),
          ),
      ],
    );
  }

  Widget? _obscureToggle(GlassTokens t) {
    if (!widget.obscureText || widget.readOnly) return null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _obscured = !_obscured),
      child: Icon(
        _obscured ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
        size: 17,
        color: t.placeholder,
      ),
    );
  }
}
