import 'package:flutter/material.dart';

import 'scopes/daily_scope_page.dart';
import 'scopes/monthly_scope_page.dart';
import 'scopes/weekly_scope_page.dart';
import 'stores/blocks_store.dart';

/// Título do AppBar por aba.
const _titles = ['Escopo diário', 'Escopo semanal', 'Escopo mensal'];

/// Shell do app: `NavigationRail` à esquerda + as três telas montadas em
/// `IndexedStack` (o estado de cada aba — semana/dia/mês — preserva ao
/// alternar). O `BlocksStore` é único e compartilhado pelos três escopos.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});

  final BlocksStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Semanal por padrão: preserva o comportamento de lançamento atual.
  int _index = 1;

  late final ValueNotifier<DateTime> _dailyDate = ValueNotifier(DateTime.now());

  @override
  void dispose() {
    _dailyDate.dispose();
    super.dispose();
  }

  /// Vem do mensal: seta a data do diário e troca para a aba dele.
  void _openDay(DateTime date) {
    _dailyDate.value = date;
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 28,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_index],
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const Text('Organize seus estudos com liberdade',
                style: TextStyle(fontSize: 13, color: Color(0xFF777785))),
          ],
        ),
        actions: [
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded)),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFEAE7FF),
            child: Text('EF', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Rail estendido (com rótulos) em telas ≥900px; recolhido abaixo.
          final extended = constraints.maxWidth >= 900;
          return Row(
            children: [
              NavigationRail(
                backgroundColor: Colors.white,
                selectedIndex: _index,
                onDestinationSelected: (index) =>
                    setState(() => _index = index),
                extended: extended,
                indicatorColor: const Color(0xFFEAE7FF),
                selectedIconTheme:
                    const IconThemeData(color: Color(0xFF6D5EF5)),
                selectedLabelTextStyle: const TextStyle(
                    color: Color(0xFF6D5EF5), fontWeight: FontWeight.w700),
                unselectedLabelTextStyle:
                    TextStyle(color: Colors.grey.shade600),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.calendar_today),
                    label: Text('Diário'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.view_week),
                    label: Text('Semanal'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.calendar_month),
                    label: Text('Mensal'),
                  ),
                ],
              ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    DailyScopePage(store: widget.store, selectedDate: _dailyDate),
                    WeeklyScopePage(store: widget.store),
                    MonthlyScopePage(
                      store: widget.store,
                      onOpenDay: _openDay,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
