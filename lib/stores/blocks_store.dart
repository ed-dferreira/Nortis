import 'package:flutter/foundation.dart';

import '../database.dart';
import '../date_keys.dart';
import '../models/study_block.dart';

typedef WeekLoader = Future<Map<String, List<StudyBlock>>> Function(String weekKey);
typedef SubjectLoader = Future<List<String>> Function();

/// Acesso à persistência, isolado para os testes trocarem por um falso.
abstract class BlockRepository {
  Future<void> insert(StudyBlock block, String day, String weekKey);
  Future<void> update(StudyBlock block, String day, String weekKey);
  Future<void> delete(int id);
}

/// Persistência das matérias pré-definidas.
abstract class SubjectRepository {
  Future<void> insert(String name);
}

/// Implementação padrão que delega ao `DatabaseHelper` existente.
class DbBlockRepository implements BlockRepository {
  const DbBlockRepository();

  @override
  Future<void> insert(StudyBlock block, String day, String weekKey) =>
      DatabaseHelper.instance.insertBlock(block, day, weekKey);

  @override
  Future<void> update(StudyBlock block, String day, String weekKey) =>
      DatabaseHelper.instance.updateBlock(block, day, weekKey);

  @override
  Future<void> delete(int id) => DatabaseHelper.instance.deleteBlock(id);
}

/// Implementação padrão das matérias pré-definidas.
class DbSubjectRepository implements SubjectRepository {
  const DbSubjectRepository();

  @override
  Future<void> insert(String name) => DatabaseHelper.instance.insertSubject(name);
}

/// Localização de um bloco dentro do cache.
class _Location {
  const _Location(this.weekKey, this.day, this.list, this.index);

  final String weekKey;
  final String day;
  final List<StudyBlock> list;
  final int index;
}

/// Fonte única de estado dos blocos: cache por `weekKey` + persistência.
class BlocksStore extends ChangeNotifier {
  BlocksStore({
    WeekLoader? loader,
    BlockRepository? repo,
    SubjectLoader? subjectLoader,
    SubjectRepository? subjectRepo,
  })  : _loader = loader ?? DatabaseHelper.instance.loadWeek,
        _repo = repo ?? const DbBlockRepository(),
        _subjectLoader = subjectLoader ?? DatabaseHelper.instance.loadSubjects,
        _subjectRepo = subjectRepo ?? const DbSubjectRepository();

  final WeekLoader _loader;
  final BlockRepository _repo;
  final SubjectLoader _subjectLoader;
  final SubjectRepository _subjectRepo;

  final Map<String, Map<String, List<StudyBlock>>> _cache = {};

  /// Chaves já carregadas via loader — `week()` pode criar estruturas vazias
  /// sem impedir que `ensureWeek` as carregue depois.
  final Set<String> _loadedWeeks = {};

  /// Garante que a semana está carregada (uma única chamada ao loader).
  Future<void> ensureWeek(String weekKey) async {
    if (_loadedWeeks.contains(weekKey)) return;
    final data = await _loader(weekKey);
    _cache[weekKey] = {
      for (final day in dayNames) day: List<StudyBlock>.of(data[day] ?? const []),
    };
    _loadedWeeks.add(weekKey);
    notifyListeners();
  }

  /// Garante que todas as semanas que intersectam o mês estão carregadas
  /// (as 5 segundas: a que contém o dia 1º e todas as que começam dentro do mês).
  Future<void> ensureMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    var monday = mondayOf(start);
    while (monday.isBefore(nextMonth)) {
      await ensureWeek(weekKeyOf(monday));
      monday = DateTime(monday.year, monday.month, monday.day + 7);
    }
  }

  /// Semana completa (sempre com as 7 listas, possivelmente vazias).
  /// Não carrega do loader — chame `ensureWeek` antes de renderizar.
  Map<String, List<StudyBlock>> week(String weekKey) {
    return _cache.putIfAbsent(
      weekKey,
      () => {for (final day in dayNames) day: <StudyBlock>[]},
    );
  }

  /// Blocos do dia da data (a semana sempre tem as 7 listas).
  List<StudyBlock> day(DateTime date) => week(weekKeyOf(date))[dayNameOf(date)]!;

  /// Adiciona ao dia, notifica e persiste com `insert`.
  Future<void> addBlock(DateTime date, StudyBlock block) async {
    final weekKey = weekKeyOf(date);
    final day = dayNameOf(date);
    week(weekKey)[day]!.add(block);
    notifyListeners();
    await _repo.insert(block, day, weekKey);
  }

  /// Aplica uma edição ao bloco no cache e persiste.
  /// Se o bloco estava em outro dia da mesma semana, comporta-se como
  /// movimentação (remove + add; delete + insert no repo), igual ao fluxo
  /// atual do diálogo quando o dia selecionado muda.
  Future<void> updateBlock(DateTime date, StudyBlock block) async {
    final weekKey = weekKeyOf(date);
    final targetDay = dayNameOf(date);
    final weekData = week(weekKey);
    final target = weekData[targetDay]!;
    final targetIndex = target.indexWhere((b) => b.id == block.id);

    if (targetIndex >= 0) {
      // Edição no próprio dia: substitui no lugar, preservando a ordem.
      if (!identical(target[targetIndex], block)) {
        target[targetIndex] = block;
      }
      notifyListeners();
      await _repo.update(block, targetDay, weekKey);
      return;
    }

    String? previousDay;
    for (final entry in weekData.entries) {
      if (entry.value.any((b) => b.id == block.id)) {
        previousDay = entry.key;
        break;
      }
    }

    if (previousDay != null) {
      // Dia mudou dentro da mesma semana: remove + add, delete + insert.
      weekData[previousDay]!.removeWhere((b) => b.id == block.id);
      target.add(block);
      notifyListeners();
      await _repo.delete(block.id);
      await _repo.insert(block, targetDay, weekKey);
      return;
    }

    // Bloco não está no cache: estado não muda, mas persiste a edição.
    // (não deve acontecer; o chamador carrega a semana antes de editar)
    notifyListeners();
    await _repo.update(block, targetDay, weekKey);
  }

  /// Move o bloco de um dia para outro (dentro da semana ou entre semanas).
  /// Carrega a semana de destino antes de mexer no cache; persiste com
  /// `delete` + `insert` (o dia/semana do bloco mudam de linha na tabela).
  Future<void> moveBlock(StudyBlock block, DateTime from, DateTime to) async {
    final fromWeekKey = weekKeyOf(from);
    final toWeekKey = weekKeyOf(to);
    final toDay = dayNameOf(to);

    await ensureWeek(fromWeekKey);
    await ensureWeek(toWeekKey);

    final location = _locate(block.id);
    location?.list.removeAt(location.index);
    week(toWeekKey)[toDay]!.add(block);
    notifyListeners();

    await _repo.delete(block.id);
    await _repo.insert(block, toDay, toWeekKey);
  }

  /// Remove o bloco do cache (pelo id) e apaga a linha correspondente.
  Future<void> removeBlock(StudyBlock block) async {
    final location = _locate(block.id);
    location?.list.removeAt(location.index);
    notifyListeners();
    await _repo.delete(block.id);
  }

  /// Reordena apenas em memória — o schema não guarda posição.
  void reorderBlock(String weekKey, String day, int oldIndex, int newIndex) {
    final list = week(weekKey)[day]!;
    final block = list.removeAt(oldIndex);
    list.insert(newIndex, block);
    notifyListeners();
  }

  /// Alterna `pending` <-> `done` (e `inProgress` -> `done`) e persiste.
  Future<void> toggleDone(StudyBlock block) async {
    final location = _locate(block.id);
    block.status = block.status == BlockStatus.done
        ? BlockStatus.pending
        : BlockStatus.done;
    notifyListeners();
    if (location == null) return;
    await _repo.update(block, location.day, location.weekKey);
  }

  /// Procura um bloco pelo id em todo o cache.
  _Location? _locate(int id) {
    for (final weekEntry in _cache.entries) {
      for (final dayEntry in weekEntry.value.entries) {
        final index = dayEntry.value.indexWhere((b) => b.id == id);
        if (index >= 0) {
          return _Location(weekEntry.key, dayEntry.key, dayEntry.value, index);
        }
      }
    }
    return null;
  }

  /// Resumo do mês: `total`/`completed` contam apenas blocos em datas dentro
  /// do mês; `byDate` mantém todas as datas das semanas do mês (inclusive as
  /// que derrapam para o fim do mês anterior e o começo do seguinte).
  MonthSummary summaryForMonth(DateTime month) {
    final year = month.year;
    final monthIndex = month.month;
    final start = DateTime(year, monthIndex, 1);
    final nextMonth = DateTime(year, monthIndex + 1, 1);
    var monday = mondayOf(start);

    var total = 0;
    var completed = 0;
    final counts = <String, List<int>>{}; // dateKey -> [total, completed]

    while (monday.isBefore(nextMonth)) {
      final weekData = week(weekKeyOf(monday));
      for (final entry in weekData.entries) {
        final offset = dayNames.indexOf(entry.key);
        final date = DateTime(monday.year, monday.month, monday.day + offset);
        final dayCounts =
            counts.putIfAbsent(dateKeyOf(date), () => [0, 0]);
        for (final block in entry.value) {
          dayCounts[0]++;
          if (block.status == BlockStatus.done) dayCounts[1]++;
          if (date.year == year && date.month == monthIndex) {
            total++;
            if (block.status == BlockStatus.done) completed++;
          }
        }
      }
      monday = DateTime(monday.year, monday.month, monday.day + 7);
    }

    return MonthSummary(
      total: total,
      completed: completed,
      byDate: {
        // Todas as datas das semanas do mês, inclusive as sem blocos.
        for (final entry in counts.entries)
          entry.key: DayStat(total: entry.value[0], completed: entry.value[1]),
      },
    );
  }
}

/// Estatística de um dia dentro do resumo mensal.
class DayStat {
  const DayStat({required this.total, required this.completed});

  final int total;
  final int completed;
}

/// Resumo de um mês, com contagem por data (`dateKeyOf`).
class MonthSummary {
  const MonthSummary({
    required this.total,
    required this.completed,
    required this.byDate,
  });

  final int total;
  final int completed;
  final Map<String, DayStat> byDate;
}
