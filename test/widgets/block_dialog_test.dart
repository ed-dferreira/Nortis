import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nortis/models/study_block.dart';
import 'package:nortis/stores/blocks_store.dart';
import 'package:nortis/widgets/block_dialog.dart';

/// Loader falso: devolve semanas pré-semeadas, sem tocar o banco.
class _FakeLoader {
  _FakeLoader(Map<String, Map<String, List<StudyBlock>>> weeks)
      : _weeks = weeks;

  final Map<String, Map<String, List<StudyBlock>>> _weeks;
  final List<String> calls = [];

  Future<Map<String, List<StudyBlock>>> load(String weekKey) async {
    calls.add(weekKey);
    final week = _weeks[weekKey] ?? const <String, List<StudyBlock>>{};
    return {
      for (final entry in week.entries) entry.key: List.of(entry.value),
    };
  }
}

/// Repositório falso que grava as operações persistidas.
class _FakeRepo implements BlockRepository {
  final List<String> inserts = [];
  final List<String> updates = [];
  final List<int> deletes = [];

  @override
  Future<void> insert(StudyBlock block, String day, String weekKey) async =>
      inserts.add('$day|$weekKey');

  @override
  Future<void> update(StudyBlock block, String day, String weekKey) async =>
      updates.add('$day|$weekKey');

  @override
  Future<void> delete(int id) async => deletes.add(id);
}

void main() {
  testWidgets('Diálogo cria bloco no dia pedido', (tester) async {
    final loader = _FakeLoader({});
    final repo = _FakeRepo();
    final store = BlocksStore(loader: loader.load, repo: repo);

    BuildContext? dialogHost;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            dialogHost = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ));

    showBlockDialog(dialogHost!, store: store, date: DateTime(2026, 10, 28));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Conteúdo'),
      'Revisar funções',
    );
    // Deixa o frame do `onChanged` pintar o Salvar habilitado.
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(store.day(DateTime(2026, 10, 28)), hasLength(1));
    expect(store.day(DateTime(2026, 10, 28)).single.title, 'Revisar funções');
    expect(store.day(DateTime(2026, 10, 28)).single.subject, 'Geral');
    expect(repo.inserts, contains('Quarta|2026-10-26'));
  });

  testWidgets('Diálogo editar trocando de dia move sem duplicar', (tester) async {
    final loader = _FakeLoader({
      '2026-10-26': {
        'Quarta': [
          StudyBlock(
            id: 1,
            title: 'Revisar funções',
            subject: 'Matemática',
            duration: '1h',
            color: const Color(0xFFEAE7FF),
          ),
        ],
      },
    });
    final repo = _FakeRepo();
    final store = BlocksStore(loader: loader.load, repo: repo);
    await store.ensureWeek('2026-10-26');
    final block = store.day(DateTime(2026, 10, 28)).single;

    BuildContext? dialogHost;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            dialogHost = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ));

    showBlockDialog(
      dialogHost!,
      store: store,
      date: DateTime(2026, 10, 28),
      block: block,
    );
    await tester.pumpAndSettle();

    // Abre o menu do dropdown (valor atual: 'Quarta') e escolhe a quinta-feira.
    await tester.tap(find.text('Quarta').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quinta').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(store.day(DateTime(2026, 10, 29)), hasLength(1));
    expect(store.day(DateTime(2026, 10, 29)).single.id, 1);
    expect(store.day(DateTime(2026, 10, 28)), isEmpty);
  });
}
