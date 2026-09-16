import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static String money(num value) => _currencyFormat.format(value);

  static String date(DateTime d) => _dateFormat.format(d);

  static String dateTime(DateTime d) => _dateTimeFormat.format(d);
}
