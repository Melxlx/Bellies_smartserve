import 'package:flutter/material.dart';

class SafeAsyncButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool isIcon;
  final Widget? icon;
  final bool isOutlined;

  const SafeAsyncButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.isIcon = false,
    this.icon,
    this.isOutlined = false,
  });

  @override
  State<SafeAsyncButton> createState() => _SafeAsyncButtonState();
}

class _SafeAsyncButtonState extends State<SafeAsyncButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOutlined) {
      if (widget.isIcon && widget.icon != null) {
        return OutlinedButton.icon(
          onPressed: _isLoading ? null : _handlePress,
          style: widget.style,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                )
              : widget.icon!,
          label: widget.child,
        );
      }
      return OutlinedButton(
        onPressed: _isLoading ? null : _handlePress,
        style: widget.style,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
              )
            : widget.child,
      );
    }

    if (widget.isIcon && widget.icon != null) {
      return ElevatedButton.icon(
        onPressed: _isLoading ? null : _handlePress,
        style: widget.style,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : widget.icon!,
        label: widget.child,
      );
    }

    return ElevatedButton(
      onPressed: _isLoading ? null : _handlePress,
      style: widget.style,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : widget.child,
    );
  }
}
