# Design: Dashboard lateral — Escopos Diário, Semanal e Mensal

Data: 2026-10-26
Status: pronto para aprovação

## Intenção

O Nortis hoje é uma tela única ("Escopo semanal"): navegação por semana, card de
progresso e 7 colunas de dias com blocos arrastáveis, persistidos no SQLite por
`weekKey` + nome do dia. Queremos uma navegação lateral que alterna entre três
escopos — **Diário**, **Semanal** e **Mensal** — todos operando sobre os mesmos
blocos. O semanal segue como centro de planejamento; o diário é uma lente de
foco sobre um dia; o mensal é acompanhamento consolidado do mês.

## Objetivos

- Shell com `NavigationRail` (Material) + `IndexedStack`, com o estado de cada
  aba preservado ao alternar (a semana/dia/mês abertos não resetam).
- Escopo Semanal: comportamento inalterado; deixa de ser `Scaffold` e passa a
  ser conteúdo do shell.
- Escopo Diário: navegação por data, faixa com os dias da semana, e os blocos
  do dia com criar/editar/excluir/marcar concluído.
- Escopo Mensal: calendário do mês com densidade de blocos e conclusão por dia;
  tocar num dia abre o Escopo Diário daquela data.

## Não-objetivos

- Novo schema, migração de banco ou consulta por intervalo de datas.
- Criação/edição de blocos direto pela grade mensal.
- Sincronização, contas de usuário, notificações.
- Alternar o status "em progresso" (só `pending`/`done` terão UI).

## Restrições

- Flutter + Material 3, seed `0xFF6D5EF5`, fundo `0xFFF7F7FB`, fonte Arial.
- `sqflite`; dados indexados por `weekKey` (segunda-feira, `'YYYY-MM-DD'`) e
  nome do dia em português (`'Segunda'`…`'Domingo'`).
- Breakpoint existente: 900px, via `LayoutBuilder`.
- `lib/main.dart` tem 704 linhas com modelo + UI + persistência misturados; o
  diálogo de bloco, o card e o `_SwipeableBlock` são privados do estado da
  página semanal e precisam ser compartilhados com o diário.

## Abordagens consideradas

- **A. Shell custom + `IndexedStack`** — mesmo benefício de estado, visual
  próprio, mais código escrito à mão.
- **B. `NavigationRail` + `IndexedStack`** — *escolhido pelo usuário*. Padrão
  Material, menos código, modo recolhido nativo para telas estreitas.
- **C. Rotas nomeadas / `GoRouter`** — descartado: dependência nova e perde o
  estado a cada troca de aba, sem ganho para 3 telas.

## Decisões tomadas na conversa

1. Diário e mensal são **lentes sobre os mesmos blocos**; nenhum dado novo.
2. Mensal é **calendário** (não lista de semanas), com card de progresso e pulo
   para o diário.
3. Modificações acontecem no diário e no semanal; o mensal é leitura +
   navegação.
4. **Fonte única de estado em memória (`BlocksStore`)**, compartilhada pelas
   três telas. Edição no diário aparece no semanal e no mensal na hora; a
   ordem arrastada no board semanal também aparece no diário. Alternativa
   descartada: cada tela ler direto do banco (deixa bloco fantasma no
   `IndexedStack` e perde a ordem, que o schema não guarda).

## Chamadas minhas (pode vetar)

4. Rail estendido (com rótulos) em telas ≥900px, recolhido (só ícones) abaixo
   disso — em vez de drawer.
5. Extrair `StudyBlock`/`BlockStatus`, o diálogo de bloco, o card de bloco e o
   card de progresso de `main.dart` para arquivos compartilhados, sem duplicar
   UI no diário. O semanal continua envolvendo seus cards com drag/swipe.
6. **Adicionar ação "marcar como concluído"** (checkbox no card, no diário e no
   semanal): o campo `status` existe no modelo e no banco, mas hoje nenhuma UI
   consegue alterá-lo — o progresso estaria eternamente em 0%, inclusive no
   calendário mensal.
7. Carregamento mensal: chamar o store por cada `weekKey` que intersecta o mês
   (cache + leituras paralelas na primeira visita) e agregar por data
   `'YYYY-MM-DD'`. Sem schema novo.
8. Limpas as infos/deprecações do `flutter analyze` nos trechos tocados pelo
   refactor (`withOpacity`, `DropdownButtonFormField.value`) e reescrito
   `test/widget_test.dart`, que hoje é o template de contador quebrado — a barra
   de verificação é `flutter analyze` limpo + `flutter test` passando.

## Estrutura de arquivos e camada de estado

```
lib/
  main.dart                     # só runApp + MaterialApp (tema)
  app_shell.dart                # NavigationRail + IndexedStack + AppBar
  stores/
    blocks_store.dart           # fonte única de estado (ChangeNotifier)
  scopes/
    weekly_scope_page.dart      # página atual, sem o Scaffold, lendo o store
    daily_scope_page.dart       # nova
    monthly_scope_page.dart     # nova
  models/
    study_block.dart            # StudyBlock + BlockStatus
  widgets/
    block_dialog.dart           # criar/editar bloco (compartilhado)
    block_card.dart             # visual do card + menu + concluir (compartilhado)
    progress_card.dart          # card de progresso (compartilhado)
  database.dart                 # inalterado (o store fica em cima do singleton)
```

### `BlocksStore` (camada de estado)

- `ChangeNotifier` único, criado no `main` e injetado nas três telas (via
  construtor, sem pacote de gestão de estado).
- Cache por `weekKey`: `ensureWeek(weekKey)` carrega do `DatabaseHelper` na
  primeira visita e passa a servir a memória; mutações (criar, editar, mover,
  reordenar, excluir, concluir) alteram o cache e persistem pelo
  `DatabaseHelper` existente, na mesma ordem já usada hoje.
- API por data e por semana para as lentes: blocos de um dia, blocos de uma
  semana, e agregado do mês (todas as `weekKey` do mês).
- Construtor aceita a função de carregamento (padrão: `loadWeek` do singleton),
  permitindo testar a agregação mensal com um loader falso — sem tocar em
  `database.dart`.

## Comportamento por tela

### Shell (`app_shell.dart`)

- Rail à esquerda, fundo branco: **Diário** (`calendar_today`), **Semanal**
  (`view_week`), **Mensal** (`calendar_month`); item ativo com fundo lilás e
  ícone roxo.
- `AppBar` sobe para o shell; título muda com a aba (`Escopo diário` /
  `escopo semanal` / `Escopo mensal`) e mantém o subtítulo e o avatar.
- `IndexedStack` com as três telas montadas; `body` seleciona pela aba.

### Escopo Semanal

- Mesmo board de hoje: navegação por semana, drag entre dias, swipe, reorder e
  diálogo — comportamento preservado.
- A página deixa de ser `Scaffold` e passa a consumir o `BlocksStore` no lugar
  do mapa `_allWeeks` privado: `_loadCurrentWeek` vira `ensureWeek`, e
  `moveBlock`/`showBlockDialog`/`_removeBlock` escrevem no store (que cuida da
  persistência). É a maior mudança do trabalho.
- Ganha o botão de "marcar concluído" no card (chamada 6).

### Escopo Diário

- Estado: data selecionada (default: hoje).
- Cabeçalho: `‹ quinta, 22 out ›` + botão **Hoje**.
- Faixa com os 7 dias da semana da data selecionada (seg–dom), com contagem de
  blocos por dia, dia ativo destacado; toque troca o dia.
- `ProgressCard` do dia.
- Lista dos blocos do dia: criar ( diálogo com o dia pré-selecionado ), editar,
  excluir, marcar concluído. Sem drag entre dias — a troca de dia é pela faixa
  ou pelo dropdown do diálogo.

### Escopo Mensal

- Cabeçalho: `‹ outubro 2026 ›` (setas mudam o mês).
- `ProgressoCard` do mês (concluídos/total do mês).
- Grade de 7 colunas (seg–dom): célula com o número do dia, contagem de blocos
  e fundo em tom de roxo proporcional ao % concluído; dia de hoje com anel;
  dias sem blocos permanecem claros.
- Tocar em qualquer dia abre o Escopo Diário naquela data (o shell troca de
  aba). Nenhuma criação/edição na grade.

## Detalhes de dados

- `weekKey(data)` = segunda-feira da semana de `data`, `'YYYY-MM-DD'` — mesma
  regra já usada pelo semanal (`_MondayDate`).
- Nome do dia em português derivado de `weekday`.
- Mês: o store resolve as `weekKey` que intersectam o mês (cache + leituras
  paralelas) e agrega por data.
- Invariante: o diálogo de bloco recebe o dia de origem e grava com a `weekKey`
  correspondente — criar e editar seguem o mesmo caminho do semanal.
- Com um store único, editar/mover/excluir/concluir em qualquer aba reflete
  imediatamente nas outras duas; nada de bloco fantasma no `IndexedStack`.

## Verificação

- `flutter analyze` limpo (incluindo as deprecações tocadas, chamada 8).
- Testes unitários: derivação de `weekKey`/dia a partir de data; agregação
  mensal e mutações do `BlocksStore` com loader falso (sem tocar no sqflite).
- `test/widget_test.dart` reescrito para substituir o template quebrado.
- `flutter test` passando.

## Fora do escopo / em aberto

- Status "em progresso" com UI.
- Persistir a aba/data ativa entre execuções do app.
