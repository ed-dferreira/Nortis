import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nortis/app_shell.dart';
import 'package:nortis/date_keys.dart';
import 'package:nortis/models/study_block.dart';
import 'package:nortis/stores/blocks_store.dart';

/// Nomes abreviados dos meses em português (formato do cabeçalho diário).
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

/// Nomes completos dos meses em português (mesmo formato do mensal).
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

/// Loader falso: semeia um bloco na semana corrente (relativo a `DateTime.now`
/// para não depender do relógio), sem tocar o banco.
Future<Map<String, List<StudyBlock>>> loadWeek(String weekKey) async {
  if (weekKey != weekKeyOf(DateTime.now())) return const {};
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

/// Repositório falso: o shell não persiste nada nos testes de navegação.
class _FakeRepo implements BlockRepository {
  @override
  Future<void> insert(StudyBlock block, String day, String weekKey) async {}

  @override
  Future<void> update(StudyBlock block, String day, String weekKey) async {}

  @override
  Future<void> delete(int id) async {}
}

BlocksStore _store() => BlocksStore(loader: loadWeek, repo: _FakeRepo());

void main() {
  testWidgets('Shell alterna escopos preservando o estado do semanal',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(home: AppShell(store: _store())));
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 1); // Semanal é o padrão
    expect(find.text('Semanal'), findsOneWidget);
    expect(find.text('Revisar funções'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(find.text('${_monthNames[now.month - 1]} ${now.year}'),
        findsOneWidget);

    await tester.tap(find.byIcon(Icons.view_week));
    await tester.pumpAndSettle();
    // IndexedStack preserva o board semanal (e o bloco continua lá).
    expect(find.text('Revisar funções'), findsOneWidget);
  });

  testWidgets('Célula do calendário leva ao diário da data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(home: AppShell(store: _store())));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final day28 = DateTime(now.year, now.month, 28);
    await tester
        .tap(find.byKey(ValueKey('month-cell-${dateKeyOf(day28)}')));
    await tester.pumpAndSettle();

    expect(find.text('Escopo diário'), findsOneWidget);
    expect(
      find.text(
          '${dayNameOf(day28).toLowerCase()}, 28 ${_months[day28.month - 1]}'),
      findsOneWidget,
    );
  });

  testWidgets('Rail estreito esconde rótulos', (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: AppShell(store: _store())));
    await tester.pumpAndSettle();

    // Abaixo de 900px: rail recolhido — só ícones e o rótulo sem espaço
    // (o Flutter mantém o `Text` do rótulo na árvore com tamanho zero).
    expect(find.byIcon(Icons.view_week), findsOneWidget);
    final narrowRail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(narrowRail.extended, isFalse);
    expect(tester.getSize(find.byType(NavigationRail)).width, lessThan(120));
    expect(tester.getSize(find.text('Semanal')), Size.zero);

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();

    // Larga o suficiente: rail estendido com rótulos visíveis.
    final wideRail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(wideRail.extended, isTrue);
    expect(tester.getRect(find.text('Semanal')).width, greaterThan(0));
    expect(tester.getSize(find.byType(NavigationRail)).width, greaterThan(200));
  });
}
