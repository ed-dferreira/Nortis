const List<String> dayNames = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

DateTime mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: date.weekday - 1));
}

String weekKeyOf(DateTime date) => _formatKey(mondayOf(date));

String dayNameOf(DateTime date) => dayNames[date.weekday - 1];

String dateKeyOf(DateTime date) {
  return _formatKey(DateTime(date.year, date.month, date.day));
}

String _formatKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
