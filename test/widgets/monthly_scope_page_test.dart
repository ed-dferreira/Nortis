import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nortis/models/study_block.dart';
import 'package:nortis/scopes/monthly_scope_page.dart';
import 'package:nortis/stores/blocks_store.dart';

/// Loader falso: devolve as semanas pré-semeadas, sem tocar o banco.
class _FakeLoader {
  _FakeLoader(this._weeks);

  final Map<String, Map<String, List<StudyBlock>>> _weeks;

  Future<Map<String, List<StudyBlock>>> load(String weekKey) async {
    final week = _weeks[weekKey] ?? const <String, List<StudyBlock>>{};
    return {
      for (final entry in week.entries) entry.key: List.of(entry.value),
    };
  }
}

/// Repositório falso sem operações (o mensal não escreve).
class _FakeRepo implements BlockRepository {
  @override
  Future<void> insert(StudyBlock block, String day, String weekKey) async {}

  @override
  Future<void> update(StudyBlock block, String day, String weekKey) async {}

  @override
  Future<void> delete(int id) async {}
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

/// Store com 1 bloco pendente em 29/set e 1 concluído em 28/out.
BlocksStore _store() {
  return BlocksStore(
    loader: _FakeLoader({
      '2026-09-28': {
        'Terça': [_block(1)],
      },
      '2026-10-26': {
        'Quarta': [_block(2, status: BlockStatus.done)],
      },
    }).load,
    repo: _FakeRepo(),
  );
}

void main() {
  testWidgets('Calendário mostra contagem e toque entrega a data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final opened = <DateTime>[];
    await tester.pumpWidget(MaterialApp(
      home: MonthlyScopePage(store: _store(), onOpenDay: opened.add),
    ));
    await tester.pumpAndSettle();

    expect(find.text('outubro 2026'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('month-cell-2026-09-29')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('month-cell-2026-10-28')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('month-cell-2026-10-28')));
    await tester.pumpAndSettle();

    expect(opened, [DateTime(2026, 10, 28)]);
  });

  testWidgets('Progresso do mês conta só o mês', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: MonthlyScopePage(store: _store(), onOpenDay: (_) {}),
    ));
    await tester.pumpAndSettle();

    // O bloco de 29/set, de fora do mês, não entra no total.
    expect(find.text('1 de 1 blocos concluídos'), findsOneWidget);
  });
}
