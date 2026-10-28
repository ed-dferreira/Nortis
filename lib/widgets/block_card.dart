import 'package:flutter/material.dart';

import '../models/study_block.dart';

/// Cartão de um bloco de estudo: fundo na cor do bloco, assunto em caixa
/// alta, título (riscado quando concluído), duração e rótulo "Concluído".
/// O ícone à esquerda conclui/reabre o bloco; o menu "Editar"/"Excluir"
/// aciona [onTap]/[onDelete].
class BlockCard extends StatelessWidget {
  const BlockCard({
    super.key,
    required this.block,
    required this.onTap,
    required this.onToggleDone,
    required this.onDelete,
  });

  final StudyBlock block;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDone = block.status == BlockStatus.done;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: block.color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              iconSize: 19,
              tooltip: isDone ? 'Reabrir bloco' : 'Concluir bloco',
              onPressed: onToggleDone,
              icon: Icon(
                isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                color: isDone ? const Color(0xFF198B68) : const Color(0xFF77718F),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(block.subject.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6D6682))),
                  const SizedBox(height: 4),
                  Text(block.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.schedule_rounded,
                        size: 14, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Text(block.duration,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700)),
                    const Spacer(),
                    if (isDone)
                      const Text('Concluído',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF198B68),
                              fontWeight: FontWeight.bold)),
                  ]),
                ],
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 18,
              onSelected: (value) {
                if (value == 'edit') onTap();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
