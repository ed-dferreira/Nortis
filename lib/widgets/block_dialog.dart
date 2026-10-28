import 'package:flutter/material.dart';

import '../date_keys.dart';
import '../models/study_block.dart';
import '../stores/blocks_store.dart';

/// Chips de duração oferecidos no diálogo.
const _durations = ['15min', '30min', '45min', '1h', '1h30', '2h', '2h30', '3h'];

/// Cria/edita um bloco de estudo.
///
/// Sem [block], salva via `store.addBlock` com `id` novo, matéria "Geral"
/// quando vazia e cor lilás padrão. Com [block], aplica as edições e persiste
/// via `store.updateBlock`; se o dia selecionado mudar, move com
/// `store.moveBlock` seguido de `store.updateBlock` (duas escritas).
/// Título vazio mantém o botão Salvar desabilitado.
Future<void> showBlockDialog(
  BuildContext context, {
  required BlocksStore store,
  required DateTime date,
  StudyBlock? block,
}) async {
  final titleController = TextEditingController(text: block?.title ?? '');
  final subjectController = TextEditingController(text: block?.subject ?? '');
  String selectedDay = dayNameOf(date);
  String selectedDuration = block?.duration ?? '1h';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(block == null ? 'Novo bloco' : 'Editar bloco'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Conteúdo'),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Matéria'),
              ),
              const SizedBox(height: 16),
              const Text('Duração',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _durations)
                    ChoiceChip(
                      label: Text(d,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      selected: selectedDuration == d,
                      onSelected: (_) =>
                          setDialogState(() => selectedDuration = d),
                      selectedColor: const Color(0xFFEAE7FF),
                      side: BorderSide(
                        color: selectedDuration == d
                            ? const Color(0xFF6D5EF5)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // `initializer` em vez do `value` deprecated.
                initialValue: selectedDay,
                decoration: const InputDecoration(labelText: 'Dia'),
                items: [
                  for (final day in dayNames)
                    DropdownMenuItem(value: day, child: Text(day)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => selectedDay = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: titleController.text.trim().isEmpty
                ? null
                : () async {
                    final target =
                        _selectedDate(date, selectedDay);
                    if (block == null) {
                      final novo = StudyBlock(
                        id: DateTime.now().microsecondsSinceEpoch,
                        title: titleController.text.trim(),
                        subject: subjectController.text.trim().isEmpty
                            ? 'Geral'
                            : subjectController.text.trim(),
                        duration: selectedDuration,
                        color: const Color(0xFFEAE7FF),
                      );
                      await store.addBlock(target, novo);
                    } else {
                      block.title = titleController.text.trim();
                      block.subject = subjectController.text.trim();
                      block.duration = selectedDuration;
                      if (!target.isAtSameMomentAs(date)) {
                        await store.moveBlock(block, date, target);
                        await store.updateBlock(target, block);
                      } else {
                        await store.updateBlock(date, block);
                      }
                    }
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

/// Data do `date` com o dia da semana trocado por [selectedDay],
/// preservando a semana (a segunda-feira) de `date`.
DateTime _selectedDate(DateTime date, String selectedDay) {
  final monday = mondayOf(date);
  final offset = dayNames.indexOf(selectedDay);
  return DateTime(
      monday.year, monday.month, monday.day + offset.clamp(0, 6));
}
