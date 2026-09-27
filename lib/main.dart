import 'package:flutter/material.dart';
import 'database.dart';

void main() => runApp(const StudyPlannerApp());

class StudyPlannerApp extends StatelessWidget {
  const StudyPlannerApp({super.key});

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
      home: const WeeklyScopePage(),
    );
  }
}

enum BlockStatus { pending, inProgress, done }

class StudyBlock {
  StudyBlock({
    required this.id,
    required this.title,
    required this.subject,
    required this.duration,
    required this.color,
    this.status = BlockStatus.pending,
  });

  final int id;
  String title;
  String subject;
  String duration;
  Color color;
  BlockStatus status;
}

class WeeklyScopePage extends StatefulWidget {
  const WeeklyScopePage({super.key});

  @override
  State<WeeklyScopePage> createState() => _WeeklyScopePageState();
}

class _WeeklyScopePageState extends State<WeeklyScopePage> {
  DateTime _weekStart = _MondayDate(DateTime.now());

  static DateTime _MondayDate(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  String get _weekLabel {
    final months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    final s = _weekStart;
    final e = _weekEnd;
    if (s.month == e.month) {
      return '${s.day} — ${e.day} ${months[e.month - 1]}.';
    }
    return '${s.day} ${months[s.month - 1]} — ${e.day} ${months[e.month - 1]}.';
  }

  String _dayDate(int index) {
    final date = _weekStart.add(Duration(days: index));
    return '${date.day}/${date.month}';
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _loadCurrentWeek();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _loadCurrentWeek();
  }

  final List<String> days = const [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  String _weekKey(DateTime weekStart) =>
      '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';

  final Map<String, Map<String, List<StudyBlock>>> _allWeeks = {};

  Map<String, List<StudyBlock>> _weekData(DateTime weekStart) {
    final key = _weekKey(weekStart);
    return _allWeeks.putIfAbsent(key, () => {
      for (final d in ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'])
        d: [],
    });
  }

  Map<String, List<StudyBlock>> get blocksByDay => _weekData(_weekStart);

  @override
  void initState() {
    super.initState();
    _loadCurrentWeek();
  }

  Future<void> _loadCurrentWeek() async {
    final key = _weekKey(_weekStart);
    final data = await DatabaseHelper.instance.loadWeek(key);
    setState(() {
      _allWeeks[key] = {
        for (final d in days) d: data[d] ?? [],
      };
    });
  }

  Future<void> _saveBlock(String day, StudyBlock block) async {
    await DatabaseHelper.instance.insertBlock(block, day, _weekKey(_weekStart));
  }

  Future<void> _updateBlock(String day, StudyBlock block) async {
    await DatabaseHelper.instance.updateBlock(block, day, _weekKey(_weekStart));
  }

  Future<void> _removeBlock(StudyBlock block) async {
    await DatabaseHelper.instance.deleteBlock(block.id);
  }

  int get completed => blocksByDay.values
      .expand((blocks) => blocks)
      .where((block) => block.status == BlockStatus.done)
      .length;

  int get total => blocksByDay.values.expand((blocks) => blocks).length;

  void moveBlock(StudyBlock block, String fromDay, String toDay) {
    setState(() {
      blocksByDay[fromDay]!.removeWhere((item) => item.id == block.id);
      blocksByDay[toDay]!.add(block);
    });
    _removeBlock(block);
    _saveBlock(toDay, block);
  }

  void reorderBlock(String day, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final block = blocksByDay[day]!.removeAt(oldIndex);
      blocksByDay[day]!.insert(newIndex, block);
    });
  }

  Future<void> showBlockDialog({String? day, StudyBlock? block}) async {
    final titleController = TextEditingController(text: block?.title ?? '');
    final subjectController = TextEditingController(text: block?.subject ?? '');
    String selectedDay = day ?? 'Segunda';
    String selectedDuration = block?.duration ?? '1h';

    final durations = ['15min', '30min', '45min', '1h', '1h30', '2h', '2h30', '3h'];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(block == null ? 'Novo bloco' : 'Editar bloco'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Conteúdo'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Matéria'),
                ),
                const SizedBox(height: 16),
                const Text('Duração', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in durations)
                      ChoiceChip(
                        label: Text(d, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        selected: selectedDuration == d,
                        onSelected: (_) => setDialogState(() => selectedDuration = d),
                        selectedColor: const Color(0xFFEAE7FF),
                        side: BorderSide(
                          color: selectedDuration == d
                              ? const Color(0xFF6D5EF5)
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: 'Dia'),
                  items: days
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => selectedDay = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                setState(() {
                  if (block == null) {
                    final newBlock = StudyBlock(
                      id: DateTime.now().microsecondsSinceEpoch,
                      title: titleController.text.trim(),
                      subject: subjectController.text.trim().isEmpty
                          ? 'Geral'
                          : subjectController.text.trim(),
                      duration: selectedDuration,
                      color: const Color(0xFFEAE7FF),
                    );
                    blocksByDay[selectedDay]!.add(newBlock);
                    _saveBlock(selectedDay, newBlock);
                  } else {
                    final previousDay = blocksByDay.entries
                        .firstWhere((entry) => entry.value.contains(block))
                        .key;
                    block.title = titleController.text.trim();
                    block.subject = subjectController.text.trim();
                    block.duration = selectedDuration;
                    if (previousDay != selectedDay) {
                      blocksByDay[previousDay]!.remove(block);
                      blocksByDay[selectedDay]!.add(block);
                      _removeBlock(block);
                      _saveBlock(selectedDay, block);
                    } else {
                      _updateBlock(selectedDay, block);
                    }
                  }
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 28,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Escopo semanal', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Organize seus estudos com liberdade',
                style: TextStyle(fontSize: 13, color: Color(0xFF777785))),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
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
          final isCompact = constraints.maxWidth < 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isCompact),
                const SizedBox(height: 22),
                _buildProgressCard(),
                const SizedBox(height: 22),
                _buildWeekBoard(isCompact),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
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

  Widget _buildProgressCard() {
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF302D5B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFE9E5FF)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Progresso da semana', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 7),
                Text('$completed de $total blocos concluídos',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFBDB4FF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Text('${(progress * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        ],
      ),
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
            Text('Arraste vertical para reordenar, horizontal para trocar dia', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: isCompact ? 590 : 530,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) => _buildDayColumn(days[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildDayColumn(String day, int index) {
    final blocks = blocksByDay[day]!;
    final dateStr = _dayDate(index);
    return DragTarget<StudyBlock>(
      onAcceptWithDetails: (details) {
        final sourceDay = blocksByDay.entries.firstWhere((entry) => entry.value.contains(details.data)).key;
        if (sourceDay != day) moveBlock(details.data, sourceDay, day);
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
                      Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                  Text('${blocks.length} ${blocks.length == 1 ? 'bloco' : 'blocos'}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: blocks.isEmpty
                    ? _emptyDay(day)
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: blocks.length,
                        onReorder: (oldIndex, newIndex) => reorderBlock(day, oldIndex, newIndex),
                        itemBuilder: (context, index) {
                          final block = blocks[index];
                          return _buildDraggableBlock(day, block, index);
                        },
                      ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showBlockDialog(day: day),
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

  Widget _emptyDay(String day) {
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

  Widget _buildDraggableBlock(String day, StudyBlock block, int index) {
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
          child: SizedBox(width: 240, child: _blockCard(block, dragging: true)),
        ),
        childWhenDragging: Opacity(opacity: .25, child: _blockCard(block)),
        child: ReorderableDragStartListener(index: index, child: _blockCard(block)),
      ),
    );
  }

  void _moveBlockToAdjacentDay(String day, StudyBlock block, int direction) {
    final currentIndex = days.indexOf(day);
    final newIndex = currentIndex + direction;
    if (newIndex < 0 || newIndex >= days.length) return;
    final targetDay = days[newIndex];
    moveBlock(block, day, targetDay);
  }

  Widget _blockCard(StudyBlock block, {bool dragging = false}) {
    final isDone = block.status == BlockStatus.done;
    return GestureDetector(
      onTap: () => showBlockDialog(block: block),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: block.color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: dragging
              ? [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 14, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isDone ? Icons.check_circle_rounded : Icons.drag_indicator_rounded,
                size: 19, color: isDone ? const Color(0xFF198B68) : const Color(0xFF77718F)),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(block.subject.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6D6682))),
                  const SizedBox(height: 4),
                  Text(block.title, style: TextStyle(fontWeight: FontWeight.w700, decoration: isDone ? TextDecoration.lineThrough : null)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Text(block.duration, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const Spacer(),
                    if (isDone) const Text('Concluído', style: TextStyle(fontSize: 11, color: Color(0xFF198B68), fontWeight: FontWeight.bold)),
                  ]),
                ],
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 18,
              onSelected: (value) {
                if (value == 'edit') showBlockDialog(block: block);
                if (value == 'delete') {
                  setState(() {
                    blocksByDay.forEach((_, items) => items.remove(block));
                  });
                  _removeBlock(block);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _weekDays = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

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
    final currentIdx = _weekDays.indexOf(widget.day);
    final canGoLeft = currentIdx > 0;
    final canGoRight = currentIdx < _weekDays.length - 1;

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
