import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Digits in an emailed code. Must match Supabase's Authentication →
/// Providers → Email → "Email OTP Length" (6 by default, 6–10 allowed).
const codeLength = 6;

/// One box per digit of an emailed code.
///
/// A transparent text field lies over the boxes and takes the input, so
/// typing, deleting, pasting and the keyboard's one-time-code autofill all
/// work as in a normal field; the boxes only draw what it holds.
class CodeInput extends StatefulWidget {
  const CodeInput({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onCompleted,
  });

  final TextEditingController controller;
  final bool enabled;

  /// Called with the code once every box is filled.
  final ValueChanged<String>? onCompleted;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_redraw);
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(CodeInput old) {
    super.didUpdateWidget(old);
    if (old.controller == widget.controller) return;
    old.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _redraw() => setState(() {});

  void _changed() {
    _redraw();
    final code = widget.controller.text;
    if (code.length == codeLength) widget.onCompleted?.call(code);
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < codeLength; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _box(i, code)),
            ],
          ],
        ),
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(codeLength),
            ],
            // Invisible: the boxes draw the digits and the caret.
            showCursor: false,
            enableInteractiveSelection: false,
            style: const TextStyle(color: Colors.transparent, fontSize: 1),
            decoration: const InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _box(int i, String code) {
    // The box the next digit goes into; the last one once all are filled.
    final active =
        _focus.hasFocus &&
        widget.enabled &&
        i == code.length.clamp(0, codeLength - 1);
    return AspectRatio(
      aspectRatio: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: i < code.length
            ? Text(
                code[i],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              )
            : active
            ? Container(width: 1.5, height: 24, color: AppColors.foreground)
            : null,
      ),
    );
  }
}
