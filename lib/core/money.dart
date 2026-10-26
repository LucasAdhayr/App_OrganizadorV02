/// Dinheiro sempre em centavos inteiros (nada de double: 0,1 + 0,2 não vira
/// 0,30000000000000004).

/// 123456 -> "R$ 1.234,56"; 5 -> "R$ 0,05"; negativo vira "-R$ ...".
String fmtMoney(int cents) {
  final neg = cents < 0;
  final abs = cents.abs();
  final reais = abs ~/ 100;
  final cent = abs % 100;
  final digits = reais.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${neg ? '-' : ''}R\$ $buf,${cent.toString().padLeft(2, '0')}';
}

/// Lê o que a pessoa digitou: "12", "12,5", "12,50", "12.50", "1.234,56",
/// "R\$ 89,90". Devolve centavos, ou null se não der para entender.
int? parseMoney(String input) {
  var s = input.replaceAll('R\$', '').replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    // Vírgula é o decimal; pontos são milhares.
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d+\.\d{1,2}$').hasMatch(s)) {
    // "12.50": ponto como decimal.
  } else {
    // "1.234": pontos de milhar.
    s = s.replaceAll('.', '');
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) return null;
  final parts = s.split('.');
  final reais = int.tryParse(parts[0]);
  if (reais == null || reais > 1000000000) return null;
  final frac = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  return reais * 100 + frac;
}
