import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/core/models.dart';

void main() {
  group('Recurrence.nextAfter', () {
    test('diária: dia seguinte, ignorando o horário', () {
      const r = Recurrence(type: RecurrenceType.daily);
      expect(r.nextAfter(DateTime(2026, 10, 13, 23, 59)), DateTime(2026, 10, 14));
    });

    test('dias da semana: sexta -> segunda', () {
      const r = Recurrence(type: RecurrenceType.weekdays, weekdays: {1, 3, 5});
      // 16/10/2026 é sexta; 19/10/2026 é segunda.
      expect(r.nextAfter(DateTime(2026, 10, 16)), DateTime(2026, 10, 19));
    });

    test('a cada N dias', () {
      const r = Recurrence(type: RecurrenceType.everyNDays, interval: 3);
      expect(r.nextAfter(DateTime(2026, 10, 13)), DateTime(2026, 10, 16));
    });

    test('dia do mês 31 cai no último dia de fevereiro', () {
      const r = Recurrence(type: RecurrenceType.monthDay, dayOfMonth: 31);
      expect(r.nextAfter(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    });

    test('dia do mês vira o ano', () {
      const r = Recurrence(type: RecurrenceType.monthDay, dayOfMonth: 15);
      expect(r.nextAfter(DateTime(2026, 12, 20)), DateTime(2027, 1, 15));
    });

    test('anual 29/02 vai para o próximo ano bissexto', () {
      const r = Recurrence(type: RecurrenceType.yearly, dayOfMonth: 29, month: 2);
      expect(r.nextAfter(DateTime(2027, 3, 1)), DateTime(2028, 2, 29));
    });
  });

  group('Recurrence.firstOnOrAfter', () {
    test('inclui o próprio dia quando ele bate com a regra', () {
      const r = Recurrence(type: RecurrenceType.weekdays, weekdays: {2, 4});
      // 13/10/2026 é terça (2).
      expect(r.firstOnOrAfter(DateTime(2026, 10, 13)), DateTime(2026, 10, 13));
    });

    test('pula para o próximo dia válido', () {
      const r = Recurrence(type: RecurrenceType.weekdays, weekdays: {2, 4});
      // 14/10 é quarta; a próxima terça/quinta é quinta 15/10.
      expect(r.firstOnOrAfter(DateTime(2026, 10, 14)), DateTime(2026, 10, 15));
    });

    test('diária começa no próprio dia', () {
      const r = Recurrence(type: RecurrenceType.daily);
      expect(r.firstOnOrAfter(DateTime(2026, 10, 13)), DateTime(2026, 10, 13));
    });
  });
}
