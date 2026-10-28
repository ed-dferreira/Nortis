import 'package:flutter/material.dart';

enum BlockStatus { pending, inProgress, done }

class StudyBlock {
  StudyBlock({
    required this.id,
    required this.title,
    required this.subject,
    required this.duration,
    required this.color,
    this.status = BlockStatus.pending,
  });

  final int id;
  String title;
  String subject;
  String duration;
  Color color;
  BlockStatus status;
}
