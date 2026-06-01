import 'package:flutter/material.dart';

class RequiredFieldsHint extends StatelessWidget {
  const RequiredFieldsHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      '* Обязательное поле',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class BlurValidatedTextFormField extends StatefulWidget {
  const BlurValidatedTextFormField({
    super.key,
    required this.controller,
    required this.decoration,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    this.onFieldSubmitted,
    this.onChanged,
    this.textInputAction,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  State<BlurValidatedTextFormField> createState() =>
      _BlurValidatedTextFormFieldState();
}

class _BlurValidatedTextFormFieldState
    extends State<BlurValidatedTextFormField> {
  late final FocusNode _focusNode;
  bool _didBlur = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && !_didBlur) {
      setState(() {
        _didBlur = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      autovalidateMode: _didBlur
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      decoration: widget.decoration,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      maxLength: widget.maxLength,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      textInputAction: widget.textInputAction,
    );
  }
}
