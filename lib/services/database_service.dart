import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/detector_model.dart';
import '../models/event_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'alarm_receiver.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Таблица извещателей
    await db.execute('''
      CREATE TABLE detectors(
        id TEXT PRIMARY KEY,
        name TEXT,
        type INTEGER,
        status INTEGER,
        batteryLevel INTEGER,
        lastSeen TEXT,
        zone INTEGER,
        isActive INTEGER,
        alarmCount INTEGER,
        isArmed INTEGER,
        parameters TEXT
      )
    ''');

    // Таблица событий
    await db.execute('''
      CREATE TABLE events(
        id TEXT PRIMARY KEY,
        timestamp TEXT,
        type INTEGER,
        detectorId TEXT,
        detectorName TEXT,
        description TEXT,
        data TEXT,
        isRead INTEGER
      )
    ''');

    // Таблица настроек
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Таблица зон
    await db.execute('''
      CREATE TABLE zones(
        id INTEGER PRIMARY KEY,
        name TEXT,
        isArmed INTEGER
      )
    ''');

    // Создаем зоны по умолчанию
    for (int i = 1; i <= 8; i++) {
      await db.insert('zones', {
        'id': i,
        'name': 'Зона $i',
        'isArmed': 1,
      });
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE detectors ADD COLUMN isArmed INTEGER DEFAULT 1');
    }
  }

  // Сохранить извещатель
  Future<void> saveDetector(DetectorModel detector) async {
    final db = await database;
    await db.insert(
      'detectors',
      detector.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Сохранить список извещателей
  Future<void> saveDetectors(List<DetectorModel> detectors) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var detector in detectors) {
        await txn.insert(
          'detectors',
          detector.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // Получить все извещатели
  Future<List<DetectorModel>> getDetectors() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('detectors');

    return List.generate(maps.length, (i) {
      return DetectorModel.fromJson(maps[i]);
    });
  }

  // Получить извещатели по зоне
  Future<List<DetectorModel>> getDetectorsByZone(int zone) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'detectors',
      where: 'zone = ?',
      whereArgs: [zone],
    );

    return List.generate(maps.length, (i) {
      return DetectorModel.fromJson(maps[i]);
    });
  }

  // Обновить статус извещателя
  Future<void> updateDetectorStatus(String id, DetectorStatus status) async {
    final db = await database;
    await db.update(
      'detectors',
      {
        'status': status.index,
        'lastSeen': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Обновить состояние охраны извещателя
  Future<void> updateDetectorArmed(String id, bool isArmed) async {
    final db = await database;
    await db.update(
      'detectors',
      {'isArmed': isArmed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Обновить состояние охраны для всех извещателей в зоне
  Future<void> updateZoneArmed(int zone, bool isArmed) async {
    final db = await database;
    await db.update(
      'detectors',
      {'isArmed': isArmed ? 1 : 0},
      where: 'zone = ?',
      whereArgs: [zone],
    );

    await db.update(
      'zones',
      {'isArmed': isArmed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [zone],
    );
  }

  // Получить все зоны
  Future<List<Map<String, dynamic>>> getZones() async {
    final db = await database;
    return await db.query('zones', orderBy: 'id');
  }

  // Сохранить событие
  Future<void> saveEvent(EventModel event) async {
    final db = await database;
    await db.insert(
      'events',
      event.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Сохранить несколько событий
  Future<void> saveEvents(List<EventModel> events) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var event in events) {
        await txn.insert(
          'events',
          event.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // Получить все события
  Future<List<EventModel>> getEvents({int limit = 1000}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return EventModel.fromJson(maps[i]);
    });
  }

  // Получить непрочитанные события
  Future<List<EventModel>> getUnreadEvents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'isRead = ?',
      whereArgs: [0],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return EventModel.fromJson(maps[i]);
    });
  }

  // Отметить события как прочитанные
  Future<void> markEventsAsRead() async {
    final db = await database;
    await db.update(
      'events',
      {'isRead': 1},
      where: 'isRead = ?',
      whereArgs: [0],
    );
  }

  // Получить события за период
  Future<List<EventModel>> getEventsByDateRange(
      DateTime start,
      DateTime end
      ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return EventModel.fromJson(maps[i]);
    });
  }

  // Очистить старые события
  Future<void> cleanOldEvents({int daysToKeep = 30}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));

    await db.delete(
      'events',
      where: 'timestamp < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  // Сохранить настройку
  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Получить настройку
  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isEmpty) return null;
    return maps.first['value'];
  }

  // Очистить все данные
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('detectors');
    await db.delete('events');
  }
}