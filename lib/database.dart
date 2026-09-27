import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'main.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'nortis.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE blocks (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            subject TEXT NOT NULL,
            duration TEXT NOT NULL,
            color INTEGER NOT NULL,
            status INTEGER NOT NULL DEFAULT 0,
            day TEXT NOT NULL,
            weekKey TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> insertBlock(StudyBlock block, String day, String weekKey) async {
    final database = await db;
    await database.insert(
      'blocks',
      _toMap(block, day, weekKey),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertBlocks(List<StudyBlock> blocks, String day, String weekKey) async {
    final database = await db;
    final batch = database.batch();
    for (final block in blocks) {
      batch.insert('blocks', _toMap(block, day, weekKey),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteBlock(int id) async {
    final database = await db;
    await database.delete('blocks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateBlock(StudyBlock block, String day, String weekKey) async {
    final database = await db;
    await database.update(
      'blocks',
      _toMap(block, day, weekKey),
      where: 'id = ?',
      whereArgs: [block.id],
    );
  }

  Future<void> deleteWeek(String weekKey) async {
    final database = await db;
    await database.delete('blocks', where: 'weekKey = ?', whereArgs: [weekKey]);
  }

  Future<Map<String, List<StudyBlock>>> loadWeek(String weekKey) async {
    final database = await db;
    final rows = await database.query('blocks', where: 'weekKey = ?', whereArgs: [weekKey]);
    final result = <String, List<StudyBlock>>{};
    for (final row in rows) {
      final day = row['day'] as String;
      result.putIfAbsent(day, () => []).add(_fromMap(row));
    }
    return result;
  }

  Map<String, dynamic> _toMap(StudyBlock block, String day, String weekKey) {
    return {
      'id': block.id,
      'title': block.title,
      'subject': block.subject,
      'duration': block.duration,
      'color': block.color.toARGB32(),
      'status': block.status.index,
      'day': day,
      'weekKey': weekKey,
    };
  }

  StudyBlock _fromMap(Map<String, dynamic> map) {
    return StudyBlock(
      id: map['id'] as int,
      title: map['title'] as String,
      subject: map['subject'] as String,
      duration: map['duration'] as String,
      color: Color(map['color'] as int),
      status: BlockStatus.values[map['status'] as int],
    );
  }
}
