String money(Object? raw) {
  final number = raw is num ? raw.toInt() : 0;
  final negative = number < 0;
  final integer = (number.abs() ~/ 100).toString();
  final grouped = integer.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final cents = (number.abs() % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}\$$grouped.$cents';
}

int parseMinor(String input, {bool allowNegative = false}) {
  final value = input.trim().replaceAll(',', '');
  final pattern = allowNegative ? RegExp(r'^-?\d{1,12}(\.\d{1,2})?$')
                                : RegExp(r'^\d{1,12}(\.\d{1,2})?$');
  if (!pattern.hasMatch(value)) throw const FormatException('Enter a valid USD amount with up to two decimal places.');
  final parts = value.split('.');
  final negative = value.startsWith('-');
  final units = int.parse(parts[0].replaceFirst('-', ''));
  final cents = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  return (negative ? -1 : 1) * (units * 100 + cents);
}

String decimalAmount(int minor) => '${minor < 0 ? '-' : ''}${minor.abs() ~/ 100}.${(minor.abs() % 100).toString().padLeft(2, '0')}';
