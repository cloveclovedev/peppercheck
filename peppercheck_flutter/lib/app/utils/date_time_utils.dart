import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

String getDayName(int dow) {
  // 0=Sunday, 6=Saturday
  switch (dow) {
    case 0:
      return t.common.days.sunday;
    case 1:
      return t.common.days.monday;
    case 2:
      return t.common.days.tuesday;
    case 3:
      return t.common.days.wednesday;
    case 4:
      return t.common.days.thursday;
    case 5:
      return t.common.days.friday;
    case 6:
      return t.common.days.saturday;
    default:
      return '';
  }
}

TimeOfDay minutesToTime(int minutes) {
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

int timeToMinutes(TimeOfDay time) {
  return time.hour * 60 + time.minute;
}

String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString()}:${m.toString().padLeft(2, '0')}';
}
