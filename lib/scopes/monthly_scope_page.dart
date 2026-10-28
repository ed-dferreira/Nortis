import 'dart:async';

import 'package:flutter/material.dart';

import '../date_keys.dart';
import '../stores/blocks_store.dart';
import '../widgets/progress_card.dart';

/// Nomes completos dos meses em português.
const _monthNames = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Cabeçalhos da grade (segunda a domingo).
const _weekdayLabels = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

/// Escopo mensal: calendário do mês com contagem e conclusão por dia.
///
/// Leitura + navegação: tocar em qualquer dia chama [onOpenDay] com aquela
/// data (o shell troca para o escopo diário e seta a data).
class MonthlyScopePage extends StatefulWidget {
  const MonthlyScopePage({
    super.key,
    required this.store,
    required this.onOpenDay,
  });

  final BlocksStore store;
  final ValueChanged<DateTime> onOpenDay;

  @override
  State<MonthlyScopePage> createState() => _MonthlyScopePageState();
}

class _MonthlyScopePageState extends State<MonthlyScopePage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    unawaited(widget.store.ensureMonth(_month));
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1, 1));
    unawaited(widget.store.ensureMonth(_month));
  }

  void _nextMonth() {
    setState(() => _month = DateTime(_month.year, _month.month + 1, 1));
    unawaited(widget.store.ensureMonth(_month));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final summary = widget.store.summaryForMonth(_month);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 22),
                ProgressCard(
                  title: 'Progresso do mês',
                  completed: summary.completed,
                  total: summary.total,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    for (final label in _weekdayLabels)
                      Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._buildWeeks(summary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: _prevMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: 8),
        Text(
          '${_monthNames[_month.month - 1]} ${_month.year}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _nextMonth,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  /// Linhas da grade: da segunda que contém o dia 1º até a domingo que
  /// contém o último dia do mês (inclui dias vizinhos, esmaecidos).
  List<Widget> _buildWeeks(MonthSummary summary) {
    final first = mondayOf(_month);
    final lastDayOfMonth = DateTime(_month.year, _month.month + 1, 0);
    final last = mondayOf(lastDayOfMonth).add(const Duration(days: 6));

    final weeks = <Widget>[];
    var day = first;
    while (!day.isAfter(last)) {
      weeks.add(
        Row(
          children: [
            for (var i = 0; i < 7; i++) _buildCell(day.add(Duration(days: i)), summary),
          ],
        ),
      );
      day = day.add(const Duration(days: 7));
    }
    return weeks;
  }

  Widget _buildCell(DateTime date, MonthSummary summary) {
    final stat = summary.byDate[dateKeyOf(date)];
    final total = stat?.total ?? 0;
    final completed = stat?.completed ?? 0;
    final ratio = total == 0 ? 0.0 : completed / total;
    final inMonth = date.month == _month.month && date.year == _month.year;
    final isToday = dateKeyOf(date) == dateKeyOf(DateTime.now());

    final background = total == 0
        ? Colors.white
        : Color.lerp(Colors.white, const Color(0xFF6D5EF5), ratio * 0.45)!;
    final foreground =
        ratio > 0.5 ? Colors.white : const Color(0xFF302D5B);

    final cell = Container(
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: isToday
            ? Border.all(color: const Color(0xFF6D5EF5), width: 2)
            : Border.all(color: const Color(0xFFE8E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: inMonth ? foreground : Colors.grey.shade400,
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: 2),
            Text(
              '$total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: inMonth ? foreground : Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );

    return Expanded(
      child: GestureDetector(
        key: ValueKey('month-cell-${dateKeyOf(date)}'),
        onTap: () =>
            widget.onOpenDay(DateTime(date.year, date.month, date.day)),
        child: inMonth ? cell : Opacity(opacity: 0.45, child: cell),
      ),
    );
  }
}
