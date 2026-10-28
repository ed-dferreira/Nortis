import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nortis/date_keys.dart';
import 'package:nortis/models/study_block.dart';
import 'package:nortis/scopes/weekly_scope_page.dart';
import 'package:nortis/stores/blocks_store.dart';

/// Loader falso: devolve a semana pré-semeada, sem tocar o banco.
Future<Map<String, List<StudyBlock>>> loadWeek(String weekKey) async {
  if (weekKey != '2026-10-26') return const {};
  return {
    'Segunda': [
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
  testWidgets('Página semanal mostra blocos vindos do store e adiciona pelo diálogo',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = BlocksStore(loader: loadWeek, repo: _FakeRepo());
    await tester.pumpWidget(MaterialApp(
      home: WeeklyScopePage(store: store),
    ));
    await tester.pumpAndSettle();

    // Bloco semeado na segunda-feira aparece na coluna correspondente.
    expect(find.text('Revisar funções'), findsOneWidget);

    // "Adicionar" da coluna Terça abre o diálogo com a data da terça-feira.
    final tuesdayIndex = dayNames.indexOf('Terça');
    final tuesdayColumn = find
        .ancestor(
          of: find.text(dateLabel(tuesdayIndex)),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    await tester.tap(find.descendant(
      of: tuesdayColumn,
      matching: find.text('Adicionar'),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Conteúdo'),
      'Física mecânica',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // O bloco chegou ao store no dia da terça-feira.
    final tuesday = store.day(DateTime(2026, 10, 27));
    expect(tuesday, hasLength(1));
    expect(tuesday.single.title, 'Física mecânica');
  });
}

/// Texto do cabeçalho da coluna `index` (dia + data), igual ao da página.
String dateLabel(int index) {
  final date = mondayOf(DateTime(2026, 10, 26)).add(Duration(days: index));
  return '${date.day}/${date.month}';
}
