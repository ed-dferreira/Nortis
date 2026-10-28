import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'stores/blocks_store.dart';

void main() => runApp(const StudyPlannerApp());

class StudyPlannerApp extends StatefulWidget {
  const StudyPlannerApp({super.key});

  @override
  State<StudyPlannerApp> createState() => _StudyPlannerAppState();
}

class _StudyPlannerAppState extends State<StudyPlannerApp> {
  /// Fonte única de estado: criada uma vez e injetada nos três escopos.
  final BlocksStore _store = BlocksStore();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Escopo semanal',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6D5EF5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),
        fontFamily: 'Arial',
      ),
      home: AppShell(store: _store),
    );
  }
}
