import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nortis/date_keys.dart';
import 'package:nortis/models/study_block.dart';
import 'package:nortis/stores/blocks_store.dart';

/// Loader falso que conta chamadas e devolve semanas pré-semeadas.
class _CountingLoader {
  _CountingLoader(Map<String, Map<String, List<StudyBlock>>> weeks)
      : _weeks = weeks;

  final Map<String, Map<String, List<StudyBlock>>> _weeks;
  final List<String> calls = [];

  Future<Map<String, List<StudyBlock>>> load(String weekKey) async {
    calls.add(weekKey);
    final week = _weeks[weekKey] ?? const <String, List<StudyBlock>>{};
    return {
      for (final entry in week.entries) entry.key: List<StudyBlock>.of(entry.value),
    };
  }
}

/// Registro de uma operação persistida pelo repositório falso.
/// Captura `statusIndex` no momento da chamada (o status do bloco pode mudar depois).
class _Op {
  _Op.insert(StudyBlock b, this.day, this.weekKey)
      : kind = 'insert',
        block = b,
        id = b.id,
        statusIndex = b.status.index;

  _Op.update(StudyBlock b, this.day, this.weekKey)
      : kind = 'update',
        block = b,
        id = b.id,
        statusIndex = b.status.index;

  _Op.delete(int this.id)
      : kind = 'delete',
        day = null,
        weekKey = null,
        block = null,
        statusIndex = null;

  final String kind;
  final StudyBlock? block;
  final int? id;
  final String? day;
  final String? weekKey;
  final int? statusIndex;
}

/// Repositório falso que grava as operações numa lista, sem tocar o banco.
class _FakeRepo implements BlockRepository {
  final List<_Op> ops = [];

  @override
  Future<void> insert(StudyBlock block, String day, String weekKey) async {
    ops.add(_Op.insert(block, day, weekKey));
  }

  @override
  Future<void> update(StudyBlock block, String day, String weekKey) async {
    ops.add(_Op.update(block, day, weekKey));
  }

  @override
  Future<void> delete(int id) async {
    ops.add(_Op.delete(id));
  }
}

StudyBlock _block(int id, {BlockStatus status = BlockStatus.pending}) {
  return StudyBlock(
    id: id,
    title: 'Bloco $id',
    subject: 'Geral',
    duration: '1h',
    color: const Color(0xFFEAE7FF),
    status: status,
  );
}

void main() {
  test('ensureWeek carrega uma vez e cacheia', () async {
    final loader = _CountingLoader({
      '2026-10-26': {
        'Segunda': [_block(1)],
      },
    });
    final repo = _FakeRepo();
    final store = BlocksStore(loader: loader.load, repo: repo);

    await store.ensureWeek('2026-10-26');
    await store.ensureWeek('2026-10-26');

    expect(loader.calls, ['2026-10-26']); // carregou só uma vez
    final week = store.week('2026-10-26');
    expect(week.keys, dayNames); // todas as 7 datas do dia
    expect(week['Segunda']!.map((b) => b.id), contains(1));
  });

  test('addBlock aparece no dia e persiste', () async {
    final loader = _CountingLoader({});
    final repo = _FakeRepo();
    final store = BlocksStore(loader: loader.load, repo: repo);
    final block = _block(1);

    await store.addBlock(DateTime(2026, 10, 28), block);

    expect(store.day(DateTime(2026, 10, 28)), contains(block));
    final inserts = repo.ops.where((o) => o.kind == 'insert').toList();
    expect(inserts, hasLength(1));
    expect(inserts.single.id, 1);
    expect(inserts.single.day, 'Quarta');
    expect(inserts.single.weekKey, '2026-10-26');
  });

  test('moveBlock entre semanas carrega a destino', () async {
    final loader = _CountingLoader({
      '2026-10-26': {
        'Quarta': [_block(1)],
      },
    });
    final repo = _FakeRepo();
    final store = BlocksStore(loader: loader.load, repo: repo);
    await store.ensureWeek('2026-10-26');
    final block = store.week('2026-10-26')['Quarta']!.single;

    await store.moveBlock(block, DateTime(2026, 10, 28), DateTime(2026, 11, 4));

    expect(loader.calls, contains('2026-11-02')); // destino carregado
    expect(store.day(DateTime(2026, 11, 4)), contains(block));
    expect(store.day(DateTime(2026, 10, 28)), isNot(contains(block)));
    // mesma ordem do código atual: delete e depois insert do destino
    expect(repo.ops.map((o) => o.kind), ['delete', 'insert']);
    expect(repo.ops.first.id, 1);
    final insert = repo.ops.last;
    expect(insert.day, 'Quarta');
    expect(insert.weekKey, '2026-11-02');
  });

  test('toggleDone alterna status e persiste', () async {
    final loader = _CountingLoader({
      '2026-10-26': {
        'Segunda': [_block(1)],
      },
    });
    final repo = _FakeRepo();
    final store = BlocksStore(loader: loader.load, repo: repo);
    await store.ensureWeek('2026-10-26');
    final block = store.week('2026-10-26')['Segunda']!.single;
    expect(block.status, BlockStatus.pending);

    await store.toggleDone(block);
    expect(block.status, BlockStatus.done);

    await store.toggleDone(block);
    expect(block.status, BlockStatus.pending);

    final updates = repo.ops.where((o) => o.kind == 'update').toList();
    expect(updates, hasLength(2));
    // status capturado no momento de cada chamada ao repo
    expect(updates.first.statusIndex, BlockStatus.done.index); // 2
    expect(updates.first.day, 'Segunda');
    expect(updates.first.weekKey, '2026-10-26');
    expect(updates.last.statusIndex, BlockStatus.pending.index);
  });

  test('removeBlock apaga do cache e do repo', () async {
    final loader = _CountingLoader({
      '2026-10-26': {
        'Segunda': [_block(1)],
      },
    });
    final repo = _FakeRepo();
    final store = BlocksStore(loader: loader.load, repo: repo);
    await store.ensureWeek('2026-10-26');
    final block = store.week('2026-10-26')['Segunda']!.single;

    await store.removeBlock(block);

    expect(store.week('2026-10-26')['Segunda'], isNot(contains(block)));
    expect(repo.ops.map((o) => o.kind), ['delete']);
    expect(repo.ops.single.id, 1);
  });

  test('reorderBlock muda a ordem em memória', () async {
    final loader = _CountingLoader({
      '2026-10-26': {
        'Segunda': [_block(1), _block(2)],
      },
    });
    final repo = _FakeRepo();
    final store = BlocksStore(loader: loader.load, repo: repo);
    await store.ensureWeek('2026-10-26');

    store.reorderBlock('2026-10-26', 'Segunda', 0, 1);

    final order = store.week('2026-10-26')['Segunda']!.map((b) => b.id).toList();
    expect(order, [2, 1]);
    expect(repo.ops, isEmpty); // schema não guarda posição
  });

  test('summaryForMonth agrega só o mês pedido', () async {
    final loader = _CountingLoader({
      '2026-09-28': {
        'Terça': [_block(1, status: BlockStatus.done), _block(2)],
      },
      '2026-10-26': {
        'Quarta': [_block(3, status: BlockStatus.done)],
      },
    });
    final repo = _FakeRepo();
    final store = BlocksStore(loader: loader.load, repo: repo);

    await store.ensureMonth(DateTime(2026, 10, 1));

    // só as 5 segundas que intersectam outubro: 28/set, 5, 12, 19 e 26/out
    expect(loader.calls, [
      '2026-09-28',
      '2026-10-05',
      '2026-10-12',
      '2026-10-19',
      '2026-10-26',
    ]);

    final summary = store.summaryForMonth(DateTime(2026, 10, 1));
    expect(summary.total, 1); // só o bloco de outubro conta
    expect(summary.completed, 1);
    expect(summary.byDate['2026-09-29']!.total, 2);
    expect(summary.byDate['2026-09-29']!.completed, 1);
    expect(summary.byDate.containsKey('2026-11-04'), isFalse); // fora das semanas do mês
  });
}
