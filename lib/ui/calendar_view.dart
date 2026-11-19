import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../core/dates.dart';
import 'sheets.dart';
import 'term_widgets.dart';

const List<String> kMonthNames = [
  'JANEIRO',
  'FEVEREIRO',
  'MARÇO',
  'ABRIL',
  'MAIO',
  'JUNHO',
  'JULHO',
  'AGOSTO',
  'SETEMBRO',
  'OUTUBRO',
  'NOVEMBRO',
  'DEZEMBRO',
];

/// Alterna entre LISTA e CALENDÁRIO (os dois ficam no mesmo módulo).
class CalendarTabs extends StatefulWidget {
  const CalendarTabs({
    super.key,
    required this.list,
    required this.calendar,
    this.startOnCalendar = false,
  });

  final Widget list;
  final Widget calendar;
  final bool startOnCalendar;

  @override
  State<CalendarTabs> createState() => _CalendarTabsState();
}

class _CalendarTabsState extends State<CalendarTabs> {
  late bool _cal = widget.startOnCalendar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TermButton(
                  label: 'Lista',
                  icon: Icons.view_list_outlined,
                  dense: true,
                  expand: true,
                  selected: !_cal,
                  onPressed: () => setState(() => _cal = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TermButton(
                  label: 'Calendário',
                  icon: Icons.grid_view,
                  dense: true,
                  expand: true,
                  selected: _cal,
                  onPressed: () => setState(() => _cal = true),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _cal ? widget.calendar : widget.list),
      ],
    );
  }
}

/// Calendário em quadradinhos, por mês ou pelo ano inteiro.
///
/// Dia com registro = quadrado cheio (e, no mês, um número pequeno de
/// registros); dia sem registro = quadrado vazio. Hoje tem moldura dupla. A
/// semana começa na segunda. [onDay] recebe o dia tocado.
class SquareCalendar extends StatefulWidget {
  const SquareCalendar({
    super.key,
    required this.countOn,
    required this.onDay,
    this.startOnYear = false,
    this.legend = 'dia com registro',
  });

  /// Quantos registros existem no dia (0 = vazio).
  final int Function(DateTime day) countOn;
  final void Function(DateTime day) onDay;
  final bool startOnYear;
  final String legend;

  @override
  State<SquareCalendar> createState() => _SquareCalendarState();
}

class _SquareCalendarState extends State<SquareCalendar> {
  late bool _year = widget.startOnYear;
  DateTime? _month; // primeiro dia do mês mostrado
  int? _yearShown;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final now = s.now;
    final month = _month ?? DateTime(now.year, now.month);
    final year = _yearShown ?? now.year;

    void shiftMonth(int d) => setState(() => _month = DateTime(month.year, month.month + d));
    void shiftYear(int d) => setState(() => _yearShown = year + d);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          children: [
            _Arrow(Icons.chevron_left, _year ? () => shiftYear(-1) : () => shiftMonth(-1)),
            Expanded(
              child: Center(
                child: Text(
                  _year ? '$year' : '${kMonthNames[month.month - 1]} ${month.year}',
                  style: TextStyle(
                    color: p.fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            _Arrow(Icons.chevron_right, _year ? () => shiftYear(1) : () => shiftMonth(1)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TermButton(
                label: 'Mês',
                dense: true,
                expand: true,
                selected: !_year,
                onPressed: () => setState(() => _year = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TermButton(
                label: 'Ano',
                dense: true,
                expand: true,
                selected: _year,
                onPressed: () => setState(() => _year = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_year)
          Wrap(
            spacing: 12,
            runSpacing: 14,
            children: [
              for (var m = 1; m <= 12; m++)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 32 - 12) / 2,
                  child: _MiniMonth(
                    year: year,
                    month: m,
                    today: dateOnly(now),
                    countOn: widget.countOn,
                    onDay: widget.onDay,
                    onTitle: () => setState(() {
                      _year = false;
                      _month = DateTime(year, m);
                    }),
                  ),
                ),
            ],
          )
        else
          _BigMonth(
            month: month,
            today: dateOnly(now),
            countOn: widget.countOn,
            onDay: widget.onDay,
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Swatch(filled: true, today: false, color: p.fg),
            const SizedBox(width: 6),
            Text(widget.legend, style: TextStyle(color: p.dim, fontSize: 12)),
            const SizedBox(width: 16),
            _Swatch(filled: false, today: false, color: p.dim),
            const SizedBox(width: 6),
            Text('vazio', style: TextStyle(color: p.dim, fontSize: 12)),
            const SizedBox(width: 16),
            _Swatch(filled: false, today: true, color: p.fg),
            const SizedBox(width: 6),
            Text('hoje', style: TextStyle(color: p.dim, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow(this.icon, this.onTap);

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppScope.of(context).palette.fg),
        ),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.filled, required this.today, required this.color});

  final bool filled;
  final bool today;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: filled ? color : null,
          border: Border.all(color: color, width: today ? 2.5 : 1),
        ),
      );
}

/// Mês grande: dia da semana no topo e o número em cada quadrado.
class _BigMonth extends StatelessWidget {
  const _BigMonth({
    required this.month,
    required this.today,
    required this.countOn,
    required this.onDay,
  });

  final DateTime month;
  final DateTime today;
  final int Function(DateTime) countOn;
  final void Function(DateTime) onDay;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final lead = DateTime(month.year, month.month, 1).weekday - 1; // segunda = 0
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    return Column(
      children: [
        Row(
          children: [
            for (var w = 1; w <= 7; w++)
              Expanded(
                child: Center(
                  child: Text(weekdayShort(w), style: TextStyle(color: p.dim, fontSize: 11)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: () {
                    final n = r * 7 + c - lead + 1;
                    if (n < 1 || n > days) return const AspectRatio(aspectRatio: 1, child: SizedBox());
                    final day = DateTime(month.year, month.month, n);
                    final count = countOn(day);
                    final isToday = day == today;
                    final fillColor = count > 0 ? p.fg : null;
                    return Padding(
                      padding: const EdgeInsets.all(2),
                      child: GestureDetector(
                        onTap: () => onDay(day),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            key: ValueKey('cal-${day.year}-${day.month}-${day.day}'),
                            decoration: BoxDecoration(
                              color: fillColor,
                              border: Border.all(
                                color: count > 0 || isToday ? p.fg : p.line,
                                width: isToday ? 2.5 : 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    '$n',
                                    style: TextStyle(
                                      color: count > 0 ? p.bg : (isToday ? p.fg : p.dim),
                                      fontSize: 13,
                                      fontWeight: count > 0 ? FontWeight.w800 : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (count > 1)
                                  Positioned(
                                    right: 2,
                                    top: 0,
                                    child: Text(
                                      '$count',
                                      style: TextStyle(color: p.bg, fontSize: 9),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }(),
                ),
            ],
          ),
      ],
    );
  }
}

/// Mês pequeno, só quadradinhos (para a visão do ano inteiro).
class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.year,
    required this.month,
    required this.today,
    required this.countOn,
    required this.onDay,
    required this.onTitle,
  });

  final int year;
  final int month;
  final DateTime today;
  final int Function(DateTime) countOn;
  final void Function(DateTime) onDay;
  final VoidCallback onTitle;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final lead = DateTime(year, month, 1).weekday - 1;
    final days = DateTime(year, month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    var total = 0;
    for (var d = 1; d <= days; d++) {
      if (countOn(DateTime(year, month, d)) > 0) total++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTitle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text(
                  kMonthNames[month - 1].substring(0, 3),
                  style: TextStyle(color: p.fg, fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text('$total', style: TextStyle(color: p.dim, fontSize: 11)),
              ],
            ),
          ),
        ),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: () {
                    final n = r * 7 + c - lead + 1;
                    if (n < 1 || n > days) return const AspectRatio(aspectRatio: 1, child: SizedBox());
                    final day = DateTime(year, month, n);
                    final has = countOn(day) > 0;
                    final isToday = day == today;
                    return Padding(
                      padding: const EdgeInsets.all(1),
                      child: GestureDetector(
                        onTap: () => onDay(day),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            key: ValueKey('cal-${day.year}-${day.month}-${day.day}'),
                            decoration: BoxDecoration(
                              color: has ? p.fg : null,
                              border: Border.all(
                                color: has || isToday ? p.fg : p.line,
                                width: isToday ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }(),
                ),
            ],
          ),
      ],
    );
  }
}

/// Ficha de um dia: o título é a data e [children] o que houve nele.
Future<void> showDaySheet(BuildContext host, DateTime day, List<Widget> children,
    {String empty = 'Nada registrado neste dia.'}) {
  return showTermSheet<void>(host, (c) {
    final p = AppScope.of(c).palette;
    return SheetFrame(
      title: '${weekdayShort(day.weekday)} ${two(day.day)}/${two(day.month)}/${day.year}',
      children: children.isEmpty
          ? [Text('> $empty', style: TextStyle(color: p.dim, fontSize: 14))]
          : children,
    );
  });
}
