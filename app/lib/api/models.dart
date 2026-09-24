double? _num(dynamic v) => v is num ? v.toDouble() : null;
DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.pincode,
    this.highTdsAlerts = true,
    this.offlineAlerts = true,
    this.tempUnit = 'C',
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? pincode;
  final bool highTdsAlerts;
  final bool offlineAlerts;
  final String tempUnit;

  factory AppUser.fromJson(Map<String, dynamic> j) {
    final prefs = (j['prefs'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AppUser(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      phone: j['phone'] as String?,
      email: j['email'] as String?,
      pincode: j['pincode'] as String?,
      highTdsAlerts: prefs['highTdsAlerts'] as bool? ?? true,
      offlineAlerts: prefs['offlineAlerts'] as bool? ?? true,
      tempUnit: prefs['tempUnit'] as String? ?? 'C',
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }
}

class Reading {
  Reading({this.tds, this.tdsIn, this.temp, this.at});
  final double? tds;
  final double? tdsIn;
  final double? temp;
  final DateTime? at;

  factory Reading.fromJson(Map<String, dynamic> j) =>
      Reading(tds: _num(j['tds']), tdsIn: _num(j['tdsIn']), temp: _num(j['temp']), at: _date(j['at']));

  /// Percentage of dissolved solids removed, when the inlet sensor exists.
  int? get removedPercent {
    if (tdsIn == null || tds == null || tdsIn! <= 0) return null;
    return ((1 - tds! / tdsIn!) * 100).round().clamp(0, 100);
  }
}

class Device {
  Device({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.room,
    required this.online,
    this.tdsLimit,
    this.lastSeen,
    this.lastReading,
    this.firmware,
    this.openAlerts = const [],
  });

  final String id;
  final String deviceId;
  final String name;
  final String room;
  final bool online;
  final double? tdsLimit;
  final DateTime? lastSeen;
  final Reading? lastReading;
  final String? firmware;
  final List<String> openAlerts;

  static const defaultTdsLimit = 100.0;
  double get effectiveLimit => tdsLimit ?? defaultTdsLimit;
  bool get highTds => openAlerts.contains('high_tds');

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        id: j['id'] as String,
        deviceId: j['deviceId'] as String,
        name: j['name'] as String? ?? 'Purifier',
        room: j['room'] as String? ?? '',
        online: j['online'] as bool? ?? false,
        tdsLimit: _num(j['tdsLimit']),
        lastSeen: _date(j['lastSeen']),
        lastReading: j['lastReading'] is Map ? Reading.fromJson((j['lastReading'] as Map).cast<String, dynamic>()) : null,
        firmware: j['firmware'] as String?,
        openAlerts: ((j['openAlerts'] as List?) ?? const []).map((e) => e is String ? e : (e as Map)['type'] as String).toList(),
      );
}

class HistoryPoint {
  HistoryPoint(this.t, this.tds, this.temp);
  final DateTime t;
  final double? tds;
  final double? temp;

  factory HistoryPoint.fromJson(Map<String, dynamic> j) =>
      HistoryPoint(_date(j['t']) ?? DateTime.now(), _num(j['tds']), _num(j['temp']));
}
