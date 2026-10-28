import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nortis/models/study_block.dart';
import 'package:nortis/scopes/daily_scope_page.dart';
import 'package:nortis/stores/blocks_store.dart';

/// Loader falso: devolve a semana pré-semeada, sem tocar o banco.
Future<Map<String, List<StudyBlock>>> loadWeek(String weekKey) async {
  if (weekKey != '2026-10-26') return const {};
  return {
    'Quarta': [
      StudyBlock(
        id: 1,
        title: 'Revisar funções',
        subject: 'Matemática',
        duration: '1h',
        color: const Color(0xFFEAE7FF),
      ),
    ],
  };
}

/// Repositório falso que só registra as operações persistidas.
class _FakeRepo implements BlockRepository {
  final List<String> inserts = [];

  @override
  Future<void> insert(StudyBlock block, String day, String weekKey) async =>
      inserts.add('$day|$weekKey');

  @override
  Future<void> update(StudyBlock block, String day, String weekKey) async {}

  @override
  Future<void> delete(int id) async {}
}

void main() {
  testWidgets('Diário mostra os blocos do dia e cria no dia certo',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _FakeRepo();
    final store = BlocksStore(loader: loadWeek, repo: repo);
    final selectedDate = ValueNotifier(DateTime(2026, 10, 28));

    await tester.pumpWidget(MaterialApp(
      home: DailyScopePage(store: store, selectedDate: selectedDate),
    ));
    await tester.pumpAndSettle();

    // Bloco semeado na quarta aparece, com o cabeçalho do dia.
    expect(find.text('Revisar funções'), findsOneWidget);
    expect(find.text('quarta, 28 out'), findsOneWidget);

    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Conteúdo'),
      'Química orgânica',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(store.day(DateTime(2026, 10, 28)), hasLength(2));
    expect(repo.inserts, contains('Quarta|2026-10-26'));
  });

  testWidgets('Faixa da semana troca o dia', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = BlocksStore(loader: loadWeek, repo: _FakeRepo());
    final selectedDate = ValueNotifier(DateTime(2026, 10, 28));

    await tester.pumpWidget(MaterialApp(
      home: DailyScopePage(store: store, selectedDate: selectedDate),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('29')); // número do dia 29 na faixa
    await tester.pumpAndSettle();

    expect(selectedDate.value, DateTime(2026, 10, 29));
    expect(find.text('quinta, 29 out'), findsOneWidget);
  });

  testWidgets('Botão Hoje volta para hoje', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = BlocksStore(loader: loadWeek, repo: _FakeRepo());
    final selectedDate = ValueNotifier(DateTime(2026, 1, 5));

    await tester.pumpWidget(MaterialApp(
      home: DailyScopePage(store: store, selectedDate: selectedDate),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hoje'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(selectedDate.value, DateTime(now.year, now.month, now.day));
  });
}
