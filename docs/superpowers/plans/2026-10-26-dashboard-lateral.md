# Dashboard Lateral (Escopos Diário/Semanal/Mensal) — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar um shell com `NavigationRail` e três escopos — Diário, Semanal e Mensal — sobre os mesmos blocos de estudo, com estado único em memória (`BlocksStore`) sincronizando as três telas.

**Architecture:** Um `ChangeNotifier` (`BlocksStore`) vira a fonte única de estado, com cache por `weekKey` e persistência pelo `DatabaseHelper` existente (atrás de uma interface `BlockRepository`, injetável em testes). `AppShell` mantém as três telas montadas em `IndexedStack`; a semanal é refatorada para consumir o store, e as telas diária e mensal são novas. O schema do banco não muda.

**Tech Stack:** Flutter 3.47.5 stable (Dart ^3.13.2), Material 3, `sqflite` (sem dependências novas), `flutter_lints`.

**Spec:** `docs/superpowers/specs/2026-10-26-dashboard-lateral-design.md` — o plano argumenta a partir dele; leia os dois.

## Global Constraints

- Texto de UI em **português**; chaves persistidas são `weekKey` (`'YYYY-MM-DD'` da segunda-feira) e `day` (`'Segunda'`…`'Domingo'` em português) — nunca traduzir nem renomear.
- **Zero dependências novas** no `pubspec.yaml`. Schema do `sqflite` intocado (`database.dart` muda só a linha de import do modelo).
- Tema existente preservado: seed `0xFF6D5EF5`, fundo `0xFFF7F7FB`, card escuro `0xFF302D5B`, verde de conclusão `0xFF198B68`, lilás `0xFFEAE7FF`.
- Verificação ao fim de cada tarefa: `flutter analyze` (zero issues — corrija qualquer lint no código tocado) e `flutter test` (tudo verde).
- Git: `git add` sempre com caminhos explícitos; **nunca** commitar `.dart_tool/`, `.flutter-plugins-dependencies` ou `build/` (o `.gitignore` antigo os rastreia e qualquer comando Flutter os suja).
- Sem quebras de comportamento no board semanal: drag entre dias, swipe, reorder e diálogos continuam funcionando igual.

## Review Focus

Falhas que a spec implica mas nenhum teste de tarefa cobre diretamente — cada linha está ancorada no teste indicado:

1. **Mover bloco entre semanas** (ex.: arrastar da semana atual para outra): o store deve carregar a semana destino antes de escrever nela; T2 cobre com `store.moveBlock` entre duas weekKeys usando loader falso e afirmando `repo.delete` + `repo.insert` da semana destino.
2. **Dias das semanas vizinhas no calendário**: blocos em 29/set (semana que intersecta outubro) aparecem no `byDate` mas **não** entram no total do mês; T6 cobre na agregação de `summaryForMonth`.
3. **Editar bloco trocando de dia pelo diálogo**: não pode duplicar nem sumir; T3 cobre no teste do diálogo com day-changed, afirmando presença no dia novo e ausência no antigo.
4. **Rail estreito (<900px)**: rótulos somem, ícones ficam; T7 cobre com widget test em viewport estreito.
5. **Pular do mensal para o diário**: a data escolhida na grade deve aparecer no cabeçalho do diário e a aba deve trocar; T7 cobre no teste de integração do shell.

---

### Task 1: Extrair modelo e criar chaves de data

**Files:**
- Create: `lib/models/study_block.dart`
- Create: `lib/date_keys.dart`
- Modify: `lib/main.dart` (remover `StudyBlock`/`BlockStatus`, adicionar import)
- Modify: `lib/database.dart:4` (import `models/study_block.dart` no lugar de `main.dart`)
- Test: `test/date_keys_test.dart`, `test/widget_test.dart`

**Interfaces:**
- Consumes: nada (primeira tarefa).
- Produces: `enum BlockStatus { pending, inProgress, done }` e `class StudyBlock` (campos `id`, `title`, `subject`, `duration`, `color`, `status` — idênticos aos atuais) em `lib/models/study_block.dart`; em `lib/date_keys.dart`: `const List<String> dayNames` (`['Segunda', …, 'Domingo']`), `DateTime mondayOf(DateTime date)`, `String weekKeyOf(DateTime date)`, `String dayNameOf(DateTime date)`, `String dateKeyOf(DateTime date)`.

- [ ] **Step 1: Escrever o teste falhando de `date_keys`**

`test/date_keys_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nortis/date_keys.dart';

void main() {
  test('mondayOf volta para a segunda da semana', () {
    expect(mondayOf(DateTime(2026, 10, 28)), DateTime(2026, 10, 26)); // quarta -> segunda
    expect(mondayOf(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));  // domingo -> segunda anterior
    expect(mondayOf(DateTime(2026, 10, 26)), DateTime(2026, 10, 26)); // segunda -> ela mesma
  });

  test('weekKeyOf formata a segunda como YYYY-MM-DD', () {
    expect(weekKeyOf(DateTime(2026, 10, 28)), '2026-10-26');
    expect(weekKeyOf(DateTime(2026, 3, 2)), '2026-02-23'); // zero à esquerda
  });

  test('dayNameOf devolve o nome em português', () {
    expect(dayNameOf(DateTime(2026, 10, 26)), 'Segunda');
    expect(dayNameOf(DateTime(2026, 11, 1)), 'Domingo');
  });

  test('dateKeyOf formata a data como YYYY-MM-DD', () {
    expect(dateKeyOf(DateTime(2026, 10, 5)), '2026-10-05');
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar a falha**

Run: `flutter test test/date_keys_test.dart`
Expected: falha com erro de import (`uri_not_found` para `package:nortis/date_keys.dart`).

- [ ] **Step 3: Implementar `lib/date_keys.dart` e mover o modelo**

`lib/date_keys.dart`: `mondayOf` normaliza para `DateTime(date.year, date.month, date.day)` e subtrai `date.weekday - 1` dias (a regra `_MondayDate` atual); `weekKeyOf`/`dateKeyOf` usam `padLeft(2, '0')`; `dayNameOf` indexa `dayNames[date.weekday - 1]`.

`lib/models/study_block.dart`: mova `BlockStatus` e `StudyBlock` de `main.dart` sem alteração (incluindo o construtor com `status` default `pending`). `main.dart` e `database.dart` passam a importá-lo; nada mais no `main.dart` muda nesta tarefa.

- [ ] **Step 4: Rodar o teste e confirmar a aprovação**

Run: `flutter test test/date_keys_test.dart`
Expected: PASS (4 testes).

- [ ] **Step 5: Reescrever `test/widget_test.dart`**

O arquivo atual é o template de contador quebrado (falha hoje). Substitua por um teste real do modelo para manter `flutter test` verde desde aqui:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nortis/models/study_block.dart';

void main() {
  test('StudyBlock nasce pendente', () {
    final block = StudyBlock(
      id: 1, title: 'Revisar funções', subject: 'Matemática',
      duration: '1h', color: const Color(0xFFEAE7FF),
    );
    expect(block.status, BlockStatus.pending);
  });
}
```

- [ ] **Step 6: Verificação completa**

Run: `flutter analyze && flutter test`
Expected: analyze sem issues novos (o warning de import não usado do teste some com a reescrita; `_MondayDate` continua até a T4 removê-lo) e todos os testes verdes.

- [ ] **Step 7: Commit**

```bash
git add lib/models/study_block.dart lib/date_keys.dart lib/main.dart lib/database.dart test/date_keys_test.dart test/widget_test.dart
git commit -m "refactor: extrair modelo de estudo e chaves de data"
```

---

### Task 2: `BlocksStore` — fonte única de estado

**Files:**
- Create: `lib/stores/blocks_store.dart`
- Test: `test/blocks_store_test.dart`

**Interfaces:**
- Consumes: `StudyBlock`, `BlockStatus` (`lib/models/study_block.dart`), `dayNames`/`mondayOf`/`weekKeyOf`/`dayNameOf`/`dateKeyOf` (`lib/date_keys.dart`), `DatabaseHelper.instance` (`lib/database.dart`).
- Produces (tudo em `lib/stores/blocks_store.dart`):
  - `typedef WeekLoader = Future<Map<String, List<StudyBlock>>> Function(String weekKey)`
  - `abstract class BlockRepository { Future<void> insert(StudyBlock block, String day, String weekKey); Future<void> update(StudyBlock block, String day, String weekKey); Future<void> delete(int id); }` + `class DbBlockRepository implements BlockRepository` (delega ao `DatabaseHelper.instance` existente).
  - `class BlocksStore extends ChangeNotifier` com construtor `BlocksStore({WeekLoader? loader, BlockRepository? repo})` — default: `DatabaseHelper.instance.loadWeek` e `DbBlockRepository()`.
  - Métodos: `Future<void> ensureWeek(String weekKey)`, `Future<void> ensureMonth(DateTime month)`, `Map<String, List<StudyBlock>> week(String weekKey)` (todas as 7 `dayNames`, listas possivelmente vazias), `List<StudyBlock> day(DateTime date)`, `Future<void> addBlock(DateTime date, StudyBlock block)`, `Future<void> updateBlock(DateTime date, StudyBlock block)`, `Future<void> moveBlock(StudyBlock block, DateTime from, DateTime to)`, `Future<void> removeBlock(StudyBlock block)`, `void reorderBlock(String weekKey, String day, int oldIndex, int newIndex)`, `Future<void> toggleDone(StudyBlock block)`, `MonthSummary summaryForMonth(DateTime month)`.
  - `class DayStat { const DayStat({required this.total, required this.completed}); final int total; final int completed; }` e `class MonthSummary { const MonthSummary({required this.total, required this.completed, required this.byDate}); final int total; final int completed; final Map<String, DayStat> byDate; }` (`byDate` indexado por `dateKeyOf`).

- [ ] **Step 1: Escrever o teste falhando do store**

`test/blocks_store_test.dart` com um loader falso que conta chamadas e um `BlockRepository` falso que grava as operações numa lista. Casos (nome e asserção exatos):

- `'ensureWeek carrega uma vez e cacheia'`: seed com 1 bloco; duas chamadas `ensureWeek('2026-10-26')`; expect loader chamado 1 vez e `week('2026-10-26')['Segunda']` com o bloco.
- `'addBlock aparece no dia e persiste'`: `addBlock(DateTime(2026, 10, 28), block)`; expect `day(DateTime(2026, 10, 28))` contém o bloco e o repo fake registrou `insert(block, 'Quarta', '2026-10-26')`.
- `'moveBlock entre semanas carrega a destino'` (Review Focus 1): bloco em 28/out; `moveBlock(block, DateTime(2026, 10, 28), DateTime(2026, 11, 4))`; expect loader chamado também para `'2026-11-02'`, bloco presente em `day(DateTime(2026, 11, 4))`, ausente de `day(DateTime(2026, 10, 28))`, e repo registrou `delete(1)` seguido de `insert(…, 'Quarta', '2026-11-02')`.
- `'toggleDone alterna status e persiste'`: `toggleDone` muda `pending → done`, segunda chamada volta a `pending`, repo registrou `update` com `status` 2 (`BlockStatus.done.index`).
- `'removeBlock apaga do cache e do repo'`.
- `'reorderBlock muda a ordem em memória'`: dois blocos, `reorderBlock('2026-10-26', 'Segunda', 0, 1)`; expect ordem invertida e nenhuma chamada de repo (schema não guarda posição).
- `'summaryForMonth agrega só o mês pedido'` (Review Focus 2): semana `'2026-09-28'` com 2 blocos em 29/set (1 done) e semana `'2026-10-26'` com 1 bloco em 28/out (done); após `ensureMonth(DateTime(2026, 10, 1))`; expect `total == 1`, `completed == 1`, `byDate['2026-09-29']` com `total == 2` e `completed == 1`, e `byDate.containsKey('2026-11-04')` falso (fora das semanas do mês de outubro — só as 5 segundas que intersectam).

- [ ] **Step 2: Rodar o teste e confirmar a falha**

Run: `flutter test test/blocks_store_test.dart`
Expected: falha com classe não definida.

- [ ] **Step 3: Implementar `lib/stores/blocks_store.dart`**

Cache: `Map<String, Map<String, List<StudyBlock>>>` por `weekKey`; `ensureWeek` popula via loader e chama `notifyListeners()`; `week()` chama `putIfAbsent` com as 7 `dayNames` vazias. `ensureMonth` gera as segundas de `mondayOf(DateTime(mês, dia 1))` avançando 7 dias enquanto a semana intersectar o mês, e `await ensureWeek` de cada (sequencial é aceitável). Mutações: localizam o bloco no cache pelo `id`, alteram, notificam e persistem via repo na mesma ordem do código atual (`moveBlock` = `delete` + `insert` do destino). `summaryForMonth` soma por `dateKeyOf`, filtrando as datas dentro do mês para `total`/`completed` e mantendo todas as datas das semanas do mês em `byDate`.

- [ ] **Step 4: Rodar o teste e confirmar a aprovação**

Run: `flutter test test/blocks_store_test.dart`
Expected: PASS (7 testes).

- [ ] **Step 5: Verificação completa**

Run: `flutter analyze && flutter test`
Expected: limpo e verde.

- [ ] **Step 6: Commit**

```bash
git add lib/stores/blocks_store.dart test/blocks_store_test.dart
git commit -m "feat: adicionar BlocksStore como fonte única de estado"
```

---

### Task 3: Widgets compartilhados — `BlockCard`, `showBlockDialog`, `ProgressCard`

**Files:**
- Create: `lib/widgets/block_card.dart`
- Create: `lib/widgets/block_dialog.dart`
- Create: `lib/widgets/progress_card.dart`
- Test: `test/widgets/block_card_test.dart`, `test/widgets/block_dialog_test.dart`

**Interfaces:**
- Consumes: `BlocksStore` (T2), modelo e chaves de data (T1).
- Produces:
  - `class BlockCard extends StatelessWidget` — `BlockCard({super.key, required this.block, required this.onTap, required this.onToggleDone, required this.onDelete})`. Visual igual ao `_block_card` atual (fundo `block.color`, raio 14, assunto em caixa alta, duração com ícone `schedule_rounded`, rótulo "Concluído" verde quando done). O ícone à esquerda vira `IconButton`: `check_circle_rounded` verde (`0xFF198B68`) quando done, `radio_button_unchecked` cinza caso contrário, `onPressed: onToggleDone`. `PopupMenuButton` com "Editar" (`onTap`) e "Excluir" (`onDelete`).
  - `Future<void> showBlockDialog(BuildContext context, {required BlocksStore store, required DateTime date, StudyBlock? block})` — mesmos campos de hoje (Conteúdo, Matéria, chips de Duração `['15min'…'3h']`, dropdown Dia com as 7 `dayNames` da semana de `date`, default `dayNameOf(date)`). Salvar: criar → `store.addBlock(selectedDate, novo)` com `id: DateTime.now().microsecondsSinceEpoch`, `subject` fallback `'Geral'`, `color: Color(0xFFEAE7FF)`; editar sem trocar dia → `store.updateBlock(date, block)`; editar com troca → `store.moveBlock(block, date, selectedDate)` e depois `store.updateBlock(selectedDate, block)`. Título vazado continua travando o Salvar. Trocar `DropdownButtonFormField.value` por `initializer`/API não depreciada.
  - `class ProgressCard extends StatelessWidget` — `ProgressCard({super.key, required this.title, required this.completed, required this.total})`; card escuro `0xFF302D5B` com "$completed de $total blocos concluídos", barra lilás `0xFFBDB4FF` e percentual — tudo como o `_buildProgressCard` atual, com o texto do título parametrizado.

- [ ] **Step 1: Escrever os testes falhando**

`test/widgets/block_card_test.dart`:
- `'BlockCard mostra assunto e título, e conclui no toque do ícone'`: bombeia `BlockCard` dentro de `MaterialApp`/`Scaffold` com um bloco pendente e `onToggleDone` registrando chamada; expect `MATÉMÁTICA` e `Revisar funções` visíveis; toca no ícone; expect a chamada registrada.
- `'BlockCard riscar e rotular bloco concluído'`: bloco com `status: BlockStatus.done`; expect `Text('Concluído')` presente.

`test/widgets/block_dialog_test.dart`:
- `'Diálogo cria bloco no dia pedido'`: `MaterialApp` + `Store` com loader falso; `showBlockDialog(context, store:, date: DateTime(2026, 10, 28))`; digita `Revisar funções` no Conteúdo, toca Salvar; expect `store.day(DateTime(2026, 10, 28))` com 1 bloco e repo fake registrou `insert(…, 'Quarta', '2026-10-26')`.
- `'Diálogo editar trocando de dia move sem duplicar'` (Review Focus 3): seed com 1 bloco em 28/out; abre `showBlockDialog(…, date: DateTime(2026, 10, 28), block: bloco)`, seleciona 'Quinta' no dropdown, Salvar; expect `day(DateTime(2026, 10, 29))` com o bloco e `day(DateTime(2026, 10, 28))` vazio.

- [ ] **Step 2: Rodar os testes e confirmar a falha**

Run: `flutter test test/widgets`
Expected: falhas de import/classe.

- [ ] **Step 3: Implementar os três widgets**

Extraia a UI de `_blockCard`/`showBlockDialog`/`_buildProgressCard` de `lib/main.dart` para os arquivos acima, adaptando-as para as assinaturas da Interfaces. Ainda **não** apague nada do `main.dart` (a página semanal só passa a usá-los na T4). Corrija no caminho as deprecações tocadas: `withOpacity` → equivalente atual e `DropdownButtonFormField` (chamada 8 da spec).

- [ ] **Step 4: Rodar os testes e confirmar a aprovação**

Run: `flutter test test/widgets`
Expected: PASS (4 testes).

- [ ] **Step 5: Verificação completa**

Run: `flutter analyze && flutter test`
Expected: sem issues novos (os de `withOpacity`/`DropdownButtonFormField` restantes em `main.dart` somem na T4, quando a página antiga sai de lá) e testes verdes.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets test/widgets
git commit -m "feat: extrair card, diálogo e progresso compartilhados com conclusão"
```

---

### Task 4: Refatorar a página semanal para o store

**Files:**
- Create: `lib/scopes/weekly_scope_page.dart` (corpo de `_WeeklyScopePageState` + `_SwipeableBlock` movidos de `lib/main.dart`)
- Modify: `lib/main.dart` (remanescentes: `runApp`/`MaterialApp` apenas)
- Test: `test/widgets/weekly_scope_page_test.dart`

**Interfaces:**
- Consumes: `BlocksStore` (T2), `BlockCard`/`showBlockDialog`/`ProgressCard` (T3), chaves de data (T1).
- Produces: `class WeeklyScopePage extends StatefulWidget` — `WeeklyScopePage({super.key, required this.store})`; estado só com `_weekStart`; blocos lidos de `store.week(weekKeyOf(_weekStart))` dentro de um `ListenableBuilder(listenable: store)`; `ProgressCard(title: 'Progresso da semana', …)`; título de semana (`_weekLabel`) idêntico ao atual. `_SwipeableBlock` continua privado neste arquivo.

- [ ] **Step 1: Escrever o teste falhando**

`test/widgets/weekly_scope_page_test.dart`:
- `'Página semanal mostra blocos vindos do store e adiciona pelo diálogo'`: store com loader falso semeando 1 bloco em `'2026-10-26'`/`'Segunda'`; bombeia `WeeklyScopePage(store:)` em `MaterialApp` (viewport largo, ex. `Size(1400, 900)`); expect o bloco semeado visível; toca "Adicionar" da coluna Terça, digita `Física mecânica`, Salvar; expect `store.day(DateTime(2026, 10, 27))` com o bloco.

- [ ] **Step 2: Rodar o teste e confirmar a falha**

Run: `flutter test test/widgets/weekly_scope_page_test.dart`
Expected: falha (classe ainda em `main.dart`, sem `store`).

- [ ] **Step 3: Mover a página para `lib/scopes/weekly_scope_page.dart` consumindo o store**

Substitua `_allWeeks`/`_loadCurrentWeek`/`_saveBlock`/`_updateBlock`/`_removeBlock`/`moveBlock`/`reorderBlock`/`completed`/`total` pelos métodos do store (`ensureWeek` no `initState` e ao trocar de semana; mutações via store). `showBlockDialog` da página vira chamada de `showBlockDialog(context, store:, date: …, block: …)` com `date` = coluna do dia (`_weekStart.add(Duration(days: index))`). O board, o header e o `_SwipeableBlock` permanecem com o mesmo comportamento. Ao final, `lib/main.dart` contém só `main()` + `StudyPlannerApp` (que ainda usa `WeeklyScopePage` diretamente — o shell chega na T7).

- [ ] **Step 4: Rodar o teste e confirmar a aprovação**

Run: `flutter test test/widgets/weekly_scope_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Verificação completa**

Run: `flutter analyze && flutter test`
Expected: limpo e verde (o warning de `_MondayDate` desaparece — a regra vive em `mondayOf`).

- [ ] **Step 6: Commit**

```bash
git add lib/scopes/weekly_scope_page.dart lib/main.dart test/widgets/weekly_scope_page_test.dart
git commit -m "refactor: página semanal consome o BlocksStore"
```

---

### Task 5: Escopo Diário

**Files:**
- Create: `lib/scopes/daily_scope_page.dart`
- Test: `test/widgets/daily_scope_page_test.dart`

**Interfaces:**
- Consumes: `BlocksStore` (T2), `BlockCard`/`showBlockDialog`/`ProgressCard` (T3), chaves de data (T1).
- Produces: `class DailyScopePage extends StatefulWidget` — `DailyScopePage({super.key, required this.store, required this.selectedDate})` onde `selectedDate` é um `ValueNotifier<DateTime>` **possuído pelo chamador** (T7); a página ouve e também escreve `selectedDate.value` quando o usuário troca de dia.

- [ ] **Step 1: Escrever o teste falhando**

`test/widgets/daily_scope_page_test.dart`:
- `'Diário mostra os blocos do dia e cria no dia certo'`: store falso semeando 1 bloco em 28/out (`'Quarta'`); bombeia `DailyScopePage(store:, selectedDate: ValueNotifier(DateTime(2026, 10, 28)))` em `MaterialApp` largo; expect o bloco visível e `Text('quarta, 28 out')` no cabeçalho (rótulo minúsculo do dia, dia e mês abreviado); toca "Adicionar", digita `Química orgânica`, Salvar; expect `store.day(DateTime(2026, 10, 28))` com 2 blocos.
- `'Faixa da semana troca o dia'`: toca na faixa no dia `29`; expect `selectedDate.value == DateTime(2026, 10, 29)` e cabeçalho atualizado.
- `'Botão Hoje volta para hoje'`: `selectedDate` em data passada; toca "Hoje"; expect `selectedDate.value` normalizado = `DateTime.now()` normalizado.

- [ ] **Step 2: Rodar o teste e confirmar a falha**

Run: `flutter test test/widgets/daily_scope_page_test.dart`
Expected: falha por classe inexistente.

- [ ] **Step 3: Implementar `lib/scopes/daily_scope_page.dart`**

Estrutura: `ListenableBuilder(listenable: store)` sobre um `Column` com (a) cabeçalho `‹ [dia], [d] [mês] ›` (`IconButton.filledTonal` + label em minúsculas com `months` abreviados, mesmo estilo do semanal) e botão "Hoje"; (b) faixa horizontal dos 7 dias da semana de `selectedDate` (nome curto, número e contagem de blocos; dia ativo com fundo `0xFFEAE7FF` e texto `0xFF6D5EF5`); (c) `ProgressCard(title: 'Progresso do dia', …)`; (d) lista de `BlockCard` do dia (sem drag: `onTap` → `showBlockDialog(…, date: selectedDate.value, block: …)`, `onToggleDone` → `store.toggleDone`, `onDelete` → `store.removeBlock`), estado vazio com ícone e texto "Nenhum bloco neste dia"; (e) `OutlinedButton.icon` "Adicionar" → `showBlockDialog(…, date: selectedDate.value)`. Chame `store.ensureWeek(weekKeyOf(data))` antes de renderizar (no `initState` e quando `selectedDate` muda).

- [ ] **Step 4: Rodar o teste e confirmar a aprovação**

Run: `flutter test test/widgets/daily_scope_page_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 5: Verificação completa**

Run: `flutter analyze && flutter test`
Expected: limpo e verde.

- [ ] **Step 6: Commit**

```bash
git add lib/scopes/daily_scope_page.dart test/widgets/daily_scope_page_test.dart
git commit -m "feat: escopo diário com faixa de semana e blocos editáveis"
```

---

### Task 6: Escopo Mensal (calendário)

**Files:**
- Create: `lib/scopes/monthly_scope_page.dart`
- Test: `test/widgets/monthly_scope_page_test.dart`

**Interfaces:**
- Consumes: `BlocksStore` com `ensureMonth`/`summaryForMonth`/`MonthSummary`/`DayStat` (T2), `ProgressCard` (T3), `dateKeyOf`/`mondayOf` (T1).
- Produces: `class MonthlyScopePage extends StatefulWidget` — `MonthlyScopePage({super.key, required this.store, required this.onOpenDay})`, com `onOpenDay` um `ValueChanged<DateTime>` (T7 usará para trocar de aba e setar a data do diário).

- [ ] **Step 1: Escrever o teste falhando**

`test/widgets/monthly_scope_page_test.dart`:
- `'Calendário mostra contagem e toque entrega a data'` (Review Focus 2 e 5): store falso com semana `'2026-09-28'` (1 bloco em 29/set, pendente) e `'2026-10-26'` (1 bloco em 28/out, done); bombeia `MonthlyScopePage(store:, onOpenDay: registrando)` em `MaterialApp` largo com `_month` inicial outubro/2026; expect header `outubro 2026`, célula 29 exibindo `1` e célula 28 exibindo `1`; toca na célula 28; expect `onOpenDay` chamado com `DateTime(2026, 10, 28)`.
- `'Progresso do mês conta só o mês'`: expect `Text('1 de 1 blocos concluídos')` (o bloco de 29/set, de fora do mês, não entra).

- [ ] **Step 2: Rodar o teste e confirmar a falha**

Run: `flutter test test/widgets/monthly_scope_page_test.dart`
Expected: falha por classe inexistente.

- [ ] **Step 3: Implementar `lib/scopes/monthly_scope_page.dart`**

Estado: `_month` (`DateTime(ano, mês, 1)`, default = mês atual). Cabeçalho `‹ janeiro 2026 ›` (setas mudam `_month`; nomes dos meses em português). `ListenableBuilder(listenable: store)` com `ensureMonth(_month)` no `initState`/troca de mês e `summary = store.summaryForMonth(_month)`. Corpo: `ProgressCard(title: 'Progresso do mês', completed: summary.completed, total: summary.total)` + grade de 7 colunas (cabeçalhos seg–dom; células dos dias que intersectam a grade do mês, incluindo dias vizinhos exibidos esmaecidos). Célula: número do dia, contagem de blocos e fundo com tom de roxo proporcional a `completed/total` do dia (`Color.lerp(Colors.white, const Color(0xFF6D5EF5), razão * 0.45)`; célula sem blocos branca; texto branco quando razão > 0.5, senão `0xFF302D5B`); dia de hoje com `Border.all(color: 0xFF6D5EF5, width: 2)`. `GestureDetector` na célula chama `onOpenDay(DateTime(ano, mês, dia))` — qualquer dia, inclusive sem blocos.

- [ ] **Step 4: Rodar o teste e confirmar a aprovação**

Run: `flutter test test/widgets/monthly_scope_page_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 5: Verificação completa**

Run: `flutter analyze && flutter test`
Expected: limpo e verde.

- [ ] **Step 6: Commit**

```bash
git add lib/scopes/monthly_scope_page.dart test/widgets/monthly_scope_page_test.dart
git commit -m "feat: escopo mensal com calendário de conclusão"
```

---

### Task 7: `AppShell` com NavigationRail + wiring do app

**Files:**
- Create: `lib/app_shell.dart`
- Modify: `lib/main.dart` (`StudyPlannerApp` vira `StatefulWidget` que cria o `BlocksStore` e injeta no `AppShell`)
- Modify: `test/widget_test.dart` (substitui o teste de fumaça da T1 pelo teste de integração do shell)

**Interfaces:**
- Consumes: as três páginas (T4–T6) e o `BlocksStore` (T2).
- Produces: `class AppShell extends StatefulWidget` — `AppShell({super.key, required this.store})`. Estado: `int _index = 1` (default **Semanal**, preserva o comportamento de lançamento atual) e `late final ValueNotifier<DateTime> _dailyDate = ValueNotifier(DateTime.now())`.

- [ ] **Step 1: Escrever o teste falhando**

`test/widget_test.dart` (substituindo o conteúdo da T1):
- `'Shell alterna escopos preservando o estado do semanal'`: store falso semeando 1 bloco em `'2026-10-26'`/`'Segunda'`; bombeia `AppShell(store:)`; expect rail com "Semanal" selecionado e o bloco visível; toca "Mensal", expect `Text('outubro 2026')` (data de execução = 26/out/2026 — fixe a data semeada relativa a `DateTime.now()` para não depender do relógio); toca "Semanal" de volta; expect o bloco ainda visível (IndexedStack preserva).
- `'Célula do calendário leva ao diário da data'`: na aba Mensal, toca a célula do dia 28; expect "Escopo diário" no título do AppBar e `Text('quinta, 28 out')` no cabeçalho do diário.
- `'Rail estreito esconde rótulos'` (Review Focus 4): bombeia com `tester.view.physicalSize = const Size(700, 900)` (e `devicePixelRatio = 1`, redefina em `addTearDown`); expect os ícones presentes e o rótulo "Semanal" ausente; largura restaurada, rótulo presente.

- [ ] **Step 2: Rodar o teste e confirmar a falha**

Run: `flutter test test/widget_test.dart`
Expected: falha (classe inexistente).

- [ ] **Step 3: Implementar `lib/app_shell.dart` e o wiring**

`Scaffold` com `AppBar` (mova a atual para cá: título com coluna `Escopo diário|semanal|mensal` conforme `_index`, subtítulo 'Organize seus estudos com liberdade', ações de notificação + avatar `EF`) e `body: LayoutBuilder` que decide `extended = maxWidth >= 900` do `NavigationRail` (itens: Diário `calendar_today`, Semanal `view_week`, Mensal `calendar_month`; destino selecionado com fundo `0xFFEAE7FF` e ícone `0xFF6D5EF5`). Ao lado do rail, `IndexedStack(index: _index, children: [DailyScopePage(store:, selectedDate: _dailyDate), WeeklyScopePage(store:), MonthlyScopePage(store:, onOpenDay: (data) { _dailyDate.value = data; setState(() => _index = 0); })])`. Em `main.dart`, `StudyPlannerApp` mantém o tema e entrega `AppShell(store: _store)`.

- [ ] **Step 4: Rodar o teste e confirmar a aprovação**

Run: `flutter test test/widget_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 5: Verificação final do projeto**

Run: `flutter analyze && flutter test`
Expected: analyze sem issues e todos os testes verdes — a barra da spec (chamada 8).

- [ ] **Step 6: Commit**

```bash
git add lib/app_shell.dart lib/main.dart test/widget_test.dart
git commit -m "feat: shell com NavigationRail ligando os três escopos"
```
