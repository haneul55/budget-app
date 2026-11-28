import 'package:intl/intl.dart';

final _won = NumberFormat('#,###', 'ko_KR');

String formatWon(int amount) => '${_won.format(amount)}원';

/// '원' 없이 숫자만 (예: 12,300). 달력 칸처럼 좁은 곳에 쓴다.
String formatAmount(int amount) => _won.format(amount);

String formatMonth(DateTime d) => '${d.year}년 ${d.month}월';

String formatDay(DateTime d) => DateFormat('M월 d일 (E)', 'ko_KR').format(d);
