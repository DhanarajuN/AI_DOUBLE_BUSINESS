import 'package:flutter/material.dart';
import '../widgets/coming_soon_view.dart';

class PlansView extends StatelessWidget {
  const PlansView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonView(
      title: 'Plans',
      message: 'Plan comparison and pricing is still in progress.',
    );
  }
}
