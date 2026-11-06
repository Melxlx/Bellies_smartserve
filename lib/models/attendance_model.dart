enum AttendanceStatus { present, late, absent }

class AttendanceModel {
  final String userId;
  final String employeeName;
  final String position;
  final String? avatarUrl;
  final DateTime checkIn;
  DateTime? checkOut;
  final AttendanceStatus status;
  final double dailyRate;

  AttendanceModel({
    required this.userId,
    required this.employeeName,
    required this.position,
    this.avatarUrl,
    required this.checkIn,
    this.checkOut,
    this.status = AttendanceStatus.present,
    this.dailyRate = 500.0,
  });

  bool get isOnShift => checkOut == null;

  Duration get shiftDuration {
    final now = DateTime.now();
    final end = checkOut ?? now;
    final diff = end.difference(checkIn);
    return diff.isNegative ? Duration.zero : diff;
  }

  double get hoursWorked {
    return shiftDuration.inMinutes / 60.0;
  }

  String get formattedDuration {
    final totalMinutes = shiftDuration.inMinutes;
    if (totalMinutes <= 0) return "0 mins";
    final hrs = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hrs == 0) return "$mins mins";
    return "$hrs hr${hrs > 1 ? 's' : ''} $mins min${mins > 1 ? 's' : ''}";
  }

  double get estimatedPay {
    final hours = hoursWorked;
    if (hours >= 8) return dailyRate;
    if (hours <= 0) return 0.0;
    return (dailyRate / 8.0) * hours;
  }

  AttendanceModel copyWith({DateTime? checkOut, double? dailyRate, String? avatarUrl}) {
    return AttendanceModel(
      userId: userId,
      employeeName: employeeName,
      position: position,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      checkIn: checkIn,
      checkOut: checkOut ?? this.checkOut,
      status: status,
      dailyRate: dailyRate ?? this.dailyRate,
    );
  }
}
