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
      version: 7,
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
        lastSeen TEXT,
        zone INTEGER,
        zoneName TEXT,
        slot INTEGER,
        place TEXT,
        isActive INTEGER,
        alarmCount INTEGER,
        isArmed INTEGER,
        nodeType INTEGER,
        lastEventCode INTEGER
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
        isRead INTEGER,
        zoneName TEXT DEFAULT '',
        place TEXT DEFAULT '',
        detectorSlot INTEGER,
        synced INTEGER DEFAULT 0
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
    if (oldVersion < 3) {
      // Добавляем новые поля протокола; старые batteryLevel/parameters остаются, но не используются
      try { await db.execute('ALTER TABLE detectors ADD COLUMN nodeType INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE detectors ADD COLUMN lastEventCode INTEGER DEFAULT 170'); } catch (_) {}
    }
    if (oldVersion < 4) {
      // Пользовательское название конкретного места извещателя (окно, калитка, дверь и т.д.)
      try { await db.execute("ALTER TABLE detectors ADD COLUMN place TEXT DEFAULT ''"); } catch (_) {}
    }
    if (oldVersion < 5) {
      // Текстовое название зоны у каждого извещателя (склад, периметр, офис...)
      try { await db.execute("ALTER TABLE detectors ADD COLUMN zoneName TEXT DEFAULT ''"); } catch (_) {}
    }
    if (oldVersion < 6) {
      // Постоянный номер извещателя (номер квадрата). Существующим
      // извещателям номера раздаются по порядку.
      try { await db.execute('ALTER TABLE detectors ADD COLUMN slot INTEGER DEFAULT 0'); } catch (_) {}
      final rows = await db.query('detectors', columns: ['id'], orderBy: 'rowid');
      for (int i = 0; i < rows.length; i++) {
        await db.update('detectors', {'slot': i + 1},
            where: 'id = ?', whereArgs: [rows[i]['id']]);
      }
    }
    if (oldVersion < 7) {
      // Отправка журнала на сервер: данные извещателя в событии и флаг
      // синхронизации (0 — не отправлено, 1 — принято сервером,
      // 2 — отклонено сервером/слишком старое, повторно не отправляется)
      try { await db.execute("ALTER TABLE events ADD COLUMN zoneName TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE events ADD COLUMN place TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute('ALTER TABLE events ADD COLUMN detectorSlot INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE events ADD COLUMN synced INTEGER DEFAULT 0'); } catch (_) {}
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
    final List<Map<String, dynamic>> maps =
        await db.query('detectors', orderBy: 'slot');

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

  // Обновить название места извещателя (окно, калитка, дверь и т.д.)
  Future<void> updateDetectorPlace(String id, String place) async {
    final db = await database;
    await db.update(
      'detectors',
      {'place': place},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Обновить зону и место извещателя
  Future<void> updateDetectorZonePlace(String id, String zoneName, String place) async {
    final db = await database;
    await db.update(
      'detectors',
      {'zoneName': zoneName, 'place': place},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Удалить извещатель из базы
  Future<void> deleteDetector(String id) async {
    final db = await database;
    await db.delete('detectors', where: 'id = ?', whereArgs: [id]);
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

  // Получить названия всех зон в виде Map<id, name>
  Future<Map<int, String>> getZoneNames() async {
    final zones = await getZones();
    return {
      for (final z in zones) z['id'] as int: (z['name'] as String?) ?? 'Зона ${z['id']}',
    };
  }

  // Переименовать зону (пользовательское название). Если строка зоны ещё
  // не существует (например, извещатель сослался на зону, для которой нет
  // записи по умолчанию) — создаём её.
  Future<void> renameZone(int zone, String name) async {
    final db = await database;
    final updated = await db.update(
      'zones',
      {'name': name},
      where: 'id = ?',
      whereArgs: [zone],
    );
    if (updated == 0) {
      await db.insert(
        'zones',
        {'id': zone, 'name': name, 'isArmed': 1},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
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

  // ── Синхронизация с сервером ────────────────────────────────────────────

  static const int syncPending = 0;
  static const int syncDone = 1;
  static const int syncRejected = 2;

  // Неотправленные события, старые первыми
  Future<List<EventModel>> getUnsyncedEvents({int limit = 200}) async {
    final db = await database;
    final maps = await db.query(
      'events',
      where: 'synced = ?',
      whereArgs: [syncPending],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return maps.map(EventModel.fromJson).toList();
  }

  Future<int> countUnsyncedEvents() async {
    final db = await database;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM events WHERE synced = ?', [syncPending]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> setEventsSynced(List<String> ids, int status) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      // По 500 id за запрос — ограничение SQLite на число параметров
      for (var i = 0; i < ids.length; i += 500) {
        final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
        await txn.update(
          'events',
          {'synced': status},
          where: 'id IN (${List.filled(chunk.length, '?').join(',')})',
          whereArgs: chunk,
        );
      }
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

  // Удалить настройку (используется, например, чтобы "забыть" сохранённое
  // основное BLE-устройство)
  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  // Очистить только извещатели (например, при каждом новом подключении к
  // концентратору, пока актуальный список ещё не программируется/не
  // передаётся заново) — журнал событий при этом не трогаем.
  Future<void> clearDetectors() async {
    final db = await database;
    await db.delete('detectors');
  }

  // Очистить все данные
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('detectors');
    await db.delete('events');
  }

  // Сброс до заводских установок: удаляются извещатели, журнал, все
  // настройки (язык, пин-код, BT-устройство, тема) и названия зон.
  Future<void> factoryReset() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('detectors');
      await txn.delete('events');
      await txn.delete('settings');
      await txn.delete('zones');
      for (int i = 1; i <= 8; i++) {
        await txn.insert('zones', {'id': i, 'name': 'Зона $i', 'isArmed': 1});
      }
    });
  }
}
