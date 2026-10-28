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
    expect(weekKeyOf(DateTime(2026, 2, 25)), '2026-02-23'); // zero à esquerda
  });

  test('dayNameOf devolve o nome em português', () {
    expect(dayNameOf(DateTime(2026, 10, 26)), 'Segunda');
    expect(dayNameOf(DateTime(2026, 11, 1)), 'Domingo');
  });

  test('dateKeyOf formata a data como YYYY-MM-DD', () {
    expect(dateKeyOf(DateTime(2026, 10, 5)), '2026-10-05');
  });
}
