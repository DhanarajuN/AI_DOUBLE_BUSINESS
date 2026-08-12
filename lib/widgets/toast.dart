import 'package:flutter/material.dart';

/// Lightweight toast shown via the nearest ScaffoldMessenger.
class Toast {
  Toast._();

  static void show(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: duration, behavior: SnackBarBehavior.floating),
    );
  }
}
