import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class TechCafeApp extends StatelessWidget {
  const TechCafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'КафеТехникум',
      theme: AppTheme.student(),
      routerConfig: router,
    );
  }
}
