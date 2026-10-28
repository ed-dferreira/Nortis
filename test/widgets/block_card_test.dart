import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nortis/models/study_block.dart';
import 'package:nortis/widgets/block_card.dart';

StudyBlock _block({BlockStatus status = BlockStatus.pending}) {
  return StudyBlock(
    id: 1,
    title: 'Revisar funções',
    subject: 'Matemática',
    duration: '1h',
    color: const Color(0xFFEAE7FF),
    status: status,
  );
}

void main() {
  testWidgets('BlockCard mostra assunto e título, e conclui no toque do ícone',
      (tester) async {
    final togglesDone = <int>[];
    final block = _block();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlockCard(
          block: block,
          onTap: () {},
          onToggleDone: () => togglesDone.add(block.id),
          onDelete: () {},
        ),
      ),
    ));

    expect(find.text('MATEMÁTICA'), findsOneWidget);
    expect(find.text('Revisar funções'), findsOneWidget);
    expect(togglesDone, isEmpty);

    await tester.tap(find.byIcon(Icons.radio_button_unchecked));
    expect(togglesDone, hasLength(1));
    expect(togglesDone.single, block.id);
  });

  testWidgets('BlockCard riscar e rotular bloco concluído', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlockCard(
          block: _block(status: BlockStatus.done),
          onTap: () {},
          onToggleDone: () {},
          onDelete: () {},
        ),
      ),
    ));

    expect(find.text('Concluído'), findsOneWidget);
    final title = find.text('Revisar funções').evaluate().single.widget as Text;
    expect(title.style?.decoration, TextDecoration.lineThrough);
  });
}
