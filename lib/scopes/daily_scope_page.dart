import 'dart:async';

import 'package:flutter/material.dart';

import '../date_keys.dart';
import '../models/study_block.dart';
import '../stores/blocks_store.dart';
import '../widgets/block_card.dart';
import '../widgets/block_dialog.dart';
import '../widgets/progress_card.dart';

/// Meses abreviados, mesmo formato do cabeçalho semanal.
const _months = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

/// Escopo diário: foco em um dia, com faixa da semana e os blocos do dia.
///
/// A data escolhida vive em [selectedDate] — um `ValueNotifier` pertencente ao
/// chamador (o shell), para que o mensal possa apontar o diário para um dia.
/// A página ouve e também escreve o notificador quando o usuário troca de dia.
class DailyScopePage extends StatefulWidget {
  const DailyScopePage({
    super.key,
    required this.store,
    required this.selectedDate,
  });

  final BlocksStore store;
  final ValueNotifier<DateTime> selectedDate;

  @override
  State<DailyScopePage> createState() => _DailyScopePageState();
}

class _DailyScopePageState extends State<DailyScopePage> {
  DateTime get _date => widget.selectedDate.value;

  @override
  void initState() {
    super.initState();
    widget.selectedDate.addListener(_onDateChanged);
    unawaited(widget.store.ensureWeek(weekKeyOf(_date)));
  }

  @override
  void dispose() {
    widget.selectedDate.removeListener(_onDateChanged);
    super.dispose();
  }

  void _onDateChanged() {
    setState(() {});
    unawaited(widget.store.ensureWeek(weekKeyOf(_date)));
  }

  /// Normaliza para meia-noite: mantém a comparação por data limpa.
  void _goTo(DateTime date) {
    widget.selectedDate.value = DateTime(date.year, date.month, date.day);
  }

  void _goToToday() {
    final now = DateTime.now();
    _goTo(DateTime(now.year, now.month, now.day));
  }

  /// Rótulo do cabeçalho: "quarta, 28 out" (dia em minúsculas).
  String get _headerLabel {
    final d = _date;
    return '${dayNameOf(d).toLowerCase()}, ${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final blocks = widget.store.day(_date);
          final completed =
              blocks.where((block) => block.status == BlockStatus.done).length;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildWeekStrip(),
                const SizedBox(height: 22),
                ProgressCard(
                  title: 'Progresso do dia',
                  completed: completed,
                  total: blocks.length,
                ),
                const SizedBox(height: 22),
                if (blocks.isEmpty)
                  _emptyDay()
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final block in blocks) _buildBlock(block),
                    ],
                  ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () => showBlockDialog(
                    context,
                    store: widget.store,
                    date: _date,
                  ),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Adicionar'),
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                ),
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
          onPressed: () => _goTo(_date.subtract(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: 8),
        Text(_headerLabel,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => _goTo(_date.add(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(width: 16),
        OutlinedButton(onPressed: _goToToday, child: const Text('Hoje')),
      ],
    );
  }

  /// Faixa dos 7 dias da semana da data selecionada, com a contagem de blocos.
  Widget _buildWeekStrip() {
    final week = widget.store.week(weekKeyOf(_date));
    final weekStart = mondayOf(_date);
    return Row(
      children: [
        for (var i = 0; i < dayNames.length; i++)
          _stripDay(
            weekStart.add(Duration(days: i)),
            count: week[dayNames[i]]!.length,
          ),
      ],
    );
  }

  Widget _stripDay(DateTime date, {required int count}) {
    final active = dateKeyOf(date) == dateKeyOf(_date);
    final accent = active ? const Color(0xFF6D5EF5) : const Color(0xFF302D5B);
    return Expanded(
      child: GestureDetector(
        key: ValueKey('day-strip-${dateKeyOf(date)}'),
        onTap: () => _goTo(date),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFEAE7FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? const Color(0xFF6D5EF5) : const Color(0xFFE8E8F0),
            ),
          ),
          child: Column(
            children: [
              Text(
                dayNames[date.weekday - 1].substring(0, 3).toLowerCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? accent : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 3),
              Text('${date.day}',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: accent)),
              const SizedBox(height: 2),
              Text('$count',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlock(StudyBlock block) {
    return BlockCard(
      block: block,
      onTap: () => showBlockDialog(
        context,
        store: widget.store,
        date: _date,
        block: block,
      ),
      onToggleDone: () => unawaited(widget.store.toggleDone(block)),
      onDelete: () => unawaited(widget.store.removeBlock(block)),
    );
  }

  Widget _emptyDay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.event_busy_rounded, color: Colors.grey.shade400, size: 34),
          const SizedBox(height: 8),
          Text('Nenhum bloco neste dia',
              style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
