import 'dart:async';

import 'package:flutter/material.dart';

import '../date_keys.dart';
import '../models/study_block.dart';
import '../stores/blocks_store.dart';
import '../widgets/block_card.dart';
import '../widgets/block_dialog.dart';
import '../widgets/progress_card.dart';

/// Board semanal: lê os blocos do [BlocksStore] e dispara as mutações nele.
class WeeklyScopePage extends StatefulWidget {
  const WeeklyScopePage({super.key, required this.store});

  final BlocksStore store;

  @override
  State<WeeklyScopePage> createState() => _WeeklyScopePageState();
}

class _WeeklyScopePageState extends State<WeeklyScopePage> {
  DateTime _weekStart = mondayOf(DateTime.now());

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  String get _weekKey => weekKeyOf(_weekStart);

  /// Datas das colunas: a coluna `index` cai em `_weekStart + index` dias.
  DateTime _dayDate(int index) => _weekStart.add(Duration(days: index));

  Map<String, List<StudyBlock>> get _blocksByDay =>
      widget.store.week(_weekKey);

  int get _completed => _allBlocks
      .where((block) => block.status == BlockStatus.done)
      .length;

  int get _total => _allBlocks.length;

  Iterable<StudyBlock> get _allBlocks =>
      _blocksByDay.values.expand((blocks) => blocks);

  @override
  void initState() {
    super.initState();
    unawaited(widget.store.ensureWeek(_weekKey));
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    unawaited(widget.store.ensureWeek(_weekKey));
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    unawaited(widget.store.ensureWeek(_weekKey));
  }

  String get _weekLabel {
    final months = [
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
    final s = _weekStart;
    final e = _weekEnd;
    if (s.month == e.month) {
      return '${s.day} — ${e.day} ${months[e.month - 1]}.';
    }
    return '${s.day} ${months[s.month - 1]} — ${e.day} ${months[e.month - 1]}.';
  }

  String _dayLabel(int index) {
    final date = _dayDate(index);
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // O `AppBar` mora no `AppShell`; a página só tem o corpo do board.
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 22),
                  ProgressCard(
                    title: 'Progresso da semana',
                    completed: _completed,
                    total: _total,
                  ),
                  const SizedBox(height: 22),
                  _buildWeekBoard(isCompact),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(onPressed: _prevWeek, icon: const Icon(Icons.chevron_left)),
        const SizedBox(width: 8),
        Text(_weekLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        IconButton.filledTonal(onPressed: _nextWeek, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }

  Widget _buildWeekBoard(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Blocos de estudo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            // Expanded: em telas estreitas o aviso quebra linha em vez de estourar.
            Expanded(
              child: Text('Arraste vertical para reordenar, horizontal para trocar dia', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: isCompact ? 590 : 530,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dayNames.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) => _buildDayColumn(index),
          ),
        ),
      ],
    );
  }

  Widget _buildDayColumn(int index) {
    final day = dayNames[index];
    final blocks = _blocksByDay[day]!;
    return DragTarget<StudyBlock>(
      onAcceptWithDetails: (details) {
        final sourceDay = _blocksByDay.entries
            .firstWhere((entry) => entry.value.contains(details.data))
            .key;
        if (sourceDay != day) {
          unawaited(widget.store.moveBlock(
            details.data,
            _dayDate(dayNames.indexOf(sourceDay)),
            _dayDate(index),
          ));
        }
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 270,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: highlighted ? const Color(0xFFEDEBFF) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted ? const Color(0xFF6D5EF5) : const Color(0xFFE8E8F0),
              width: highlighted ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(_dayLabel(index), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                  Text('${blocks.length} ${blocks.length == 1 ? 'bloco' : 'blocos'}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: blocks.isEmpty
                    ? _emptyDay()
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: blocks.length,
                        onReorderItem: (oldIndex, newIndex) =>
                            widget.store.reorderBlock(_weekKey, day, oldIndex, newIndex),
                        itemBuilder: (context, index) =>
                            _buildBlockEntry(day, blocks[index], index),
                      ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showBlockDialog(context,
                    store: widget.store, date: _dayDate(index)),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Adicionar'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyDay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.drag_indicator_rounded, color: Colors.grey.shade400, size: 28),
          const SizedBox(height: 7),
          Text('Arraste um bloco para cá',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBlockEntry(String day, StudyBlock block, int index) {
    return _SwipeableBlock(
      key: ValueKey(block.id),
      day: day,
      block: block,
      onSwipeLeft: () => _moveBlockToAdjacentDay(day, block, 1),
      onSwipeRight: () => _moveBlockToAdjacentDay(day, block, -1),
      child: LongPressDraggable<StudyBlock>(
        data: block,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 240, child: _dragFeedback(block)),
        ),
        childWhenDragging: Opacity(opacity: .25, child: _card(block)),
        child: ReorderableDragStartListener(index: index, child: _card(block)),
      ),
    );
  }

  /// Cartão de feedback durante o arraste: mesma sombra do card antigo
  /// (`BoxShadow` desenhada em torno do card, sem mexer no `BlockCard`).
  Widget _dragFeedback(StudyBlock block) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000), // preto 15%, como antes
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: _card(block),
    );
  }

  Widget _card(StudyBlock block) {
    return BlockCard(
      block: block,
      onTap: () => showBlockDialog(context, store: widget.store, date: _dateOfBlock(block), block: block),
      onToggleDone: () => unawaited(widget.store.toggleDone(block)),
      onDelete: () => unawaited(widget.store.removeBlock(block)),
    );
  }

  /// Data atual do bloco: dia/lista em que ele está na semana visível.
  DateTime _dateOfBlock(StudyBlock block) {
    final sourceDay = _blocksByDay.entries
        .firstWhere(
          (entry) => entry.value.contains(block),
          orElse: () => _blocksByDay.entries.first,
        )
        .key;
    return _dayDate(dayNames.indexOf(sourceDay));
  }

  void _moveBlockToAdjacentDay(String day, StudyBlock block, int direction) {
    final currentIndex = dayNames.indexOf(day);
    final newIndex = currentIndex + direction;
    if (newIndex < 0 || newIndex >= dayNames.length) return;
    unawaited(widget.store.moveBlock(
      block,
      _dayDate(currentIndex),
      _dayDate(newIndex),
    ));
  }
}

class _SwipeableBlock extends StatefulWidget {
  const _SwipeableBlock({
    super.key,
    required this.day,
    required this.block,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.child,
  });

  final String day;
  final StudyBlock block;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final Widget child;

  @override
  State<_SwipeableBlock> createState() => _SwipeableBlockState();
}

class _SwipeableBlockState extends State<_SwipeableBlock> {
  double _dragOffset = 0;
  bool _swiped = false;
  double _startX = 0;
  double _startY = 0;
  bool _tracking = false;
  bool _decided = false;
  bool _isHorizontal = false;
  static const double _swipeThreshold = 80;
  static const double _decideDistance = 10;

  void _reset() {
    setState(() {
      _dragOffset = 0;
      _swiped = false;
      _tracking = false;
      _decided = false;
      _isHorizontal = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = dayNames.indexOf(widget.day);
    final canGoLeft = currentIdx > 0;
    final canGoRight = currentIdx < dayNames.length - 1;

    return Listener(
      onPointerDown: (event) {
        _startX = event.position.dx;
        _startY = event.position.dy;
        _tracking = true;
        _decided = false;
        _isHorizontal = false;
      },
      onPointerMove: (event) {
        if (!_tracking || _swiped) return;
        final dx = event.position.dx - _startX;
        final dy = event.position.dy - _startY;

        if (!_decided && (dx.abs() > _decideDistance || dy.abs() > _decideDistance)) {
          _decided = true;
          _isHorizontal = dx.abs() > dy.abs();
        }

        if (!_isHorizontal) return;

        setState(() {
          _dragOffset = dx;
          if (_dragOffset > 0 && !canGoLeft) _dragOffset = 0;
          if (_dragOffset < 0 && !canGoRight) _dragOffset = 0;
        });
      },
      onPointerUp: (event) {
        if (!_tracking || _swiped) return;
        if (_isHorizontal && _dragOffset.abs() > _swipeThreshold) {
          _swiped = true;
          if (_dragOffset > 0) {
            widget.onSwipeRight();
          } else {
            widget.onSwipeLeft();
          }
        } else {
          _reset();
        }
      },
      onPointerCancel: (_) => _reset(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_dragOffset > 20 && canGoLeft)
            Positioned(
              left: -12,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: (_dragOffset / _swipeThreshold).clamp(0.0, 1.0),
                child: const Center(
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Color(0xFF6D5EF5)),
                ),
              ),
            ),
          if (_dragOffset < -20 && canGoRight)
            Positioned(
              right: -12,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: (-_dragOffset / _swipeThreshold).clamp(0.0, 1.0),
                child: const Center(
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      size: 18, color: Color(0xFF6D5EF5)),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
