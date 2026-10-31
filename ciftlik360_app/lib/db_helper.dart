import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ciftlik360_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );

    await _migrateOldDatabases(db, dbPath);
    return db;
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE animals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tag_no TEXT NOT NULL UNIQUE,
        name TEXT,
        breed TEXT,
        gender TEXT NOT NULL,
        age TEXT,
        birth_date TEXT,
        is_pregnant INTEGER DEFAULT 0,
        insemination_date TEXT,
        est_birth_date TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE milk_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_tag TEXT NOT NULL,
        date TEXT NOT NULL,
        session TEXT NOT NULL,
        liters REAL NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE finance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        description TEXT
      )
    ''');
  }

  Future<void> _migrateOldDatabases(Database newDb, String dbPath) async {
    final oldNames = ['ciftlik360_clean.db', 'ciftlik360.db'];
    for (final oldName in oldNames) {
      final oldPath = join(dbPath, oldName);
      final exists = await databaseExists(oldPath);
      if (exists) {
        try {
          final oldDb = await openDatabase(oldPath);

          final animals = await oldDb.query('animals');
          for (var a in animals) {
            final tag = a['tag_no']?.toString() ?? '';
            if (tag.isNotEmpty) {
              final count = Sqflite.firstIntValue(
                await newDb.rawQuery('SELECT COUNT(*) FROM animals WHERE tag_no = ?', [tag]),
              ) ?? 0;

              if (count == 0) {
                await newDb.insert('animals', {
                  'tag_no': tag,
                  'name': a['name'] ?? '',
                  'breed': a['breed'] ?? 'Simental',
                  'gender': a['gender'] ?? 'Dişi',
                  'age': a['age'] ?? (a['birth_date'] != null ? 'Doğum: ${a['birth_date']}' : null),
                  'birth_date': a['birth_date'],
                  'is_pregnant': a['is_pregnant'] ?? 0,
                  'insemination_date': a['insemination_date'],
                  'est_birth_date': a['est_birth_date'],
                  'notes': a['notes'],
                });
              }
            }
          }

          final milk = await oldDb.query('milk_records');
          for (var m in milk) {
            final liters = (m['liters'] as num?)?.toDouble() ?? 0.0;
            if (liters > 0) {
              final existsCount = Sqflite.firstIntValue(
                await newDb.rawQuery(
                  'SELECT COUNT(*) FROM milk_records WHERE date = ? AND session = ? AND liters = ?',
                  [m['date'], m['session'], liters],
                ),
              ) ?? 0;

              if (existsCount == 0) {
                await newDb.insert('milk_records', {
                  'animal_tag': m['animal_tag'] ?? 'Genel Sürü',
                  'date': m['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'session': m['session'] ?? 'Sabah',
                  'liters': liters,
                  'note': m['note'],
                });
              }
            }
          }

          final finance = await oldDb.query('finance_records');
          for (var f in finance) {
            final amount = (f['amount'] as num?)?.toDouble() ?? 0.0;
            if (amount > 0) {
              final existsCount = Sqflite.firstIntValue(
                await newDb.rawQuery(
                  'SELECT COUNT(*) FROM finance_records WHERE date = ? AND category = ? AND amount = ?',
                  [f['date'], f['category'], amount],
                ),
              ) ?? 0;

              if (existsCount == 0) {
                await newDb.insert('finance_records', {
                  'type': f['type'] ?? 'Gelir',
                  'category': f['category'] ?? '',
                  'amount': amount,
                  'date': f['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'description': f['description'],
                });
              }
            }
          }

          await oldDb.close();
        } catch (_) {}
      }
    }
  }

  // --- HAYVAN İŞLEMLERİ ---
  Future<List<Animal>> getAnimals({String? genderFilter}) async {
    final db = await instance.database;
    String? where;
    List<dynamic>? whereArgs;

    if (genderFilter != null && genderFilter != 'Tümü') {
      where = 'gender = ?';
      whereArgs = [genderFilter];
    }

    final maps = await db.query('animals', where: where, whereArgs: whereArgs, orderBy: 'id DESC');
    return maps.map((e) => Animal.fromMap(e)).toList();
  }

  Future<int> addAnimal(Animal animal) async {
    final db = await instance.database;
    return await db.insert('animals', animal.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateAnimal(Animal animal) async {
    final db = await instance.database;
    return await db.update('animals', animal.toMap(), where: 'id = ?', whereArgs: [animal.id]);
  }

  Future<int> setAnimalPregnancy(int id, bool isPregnant, {String? inseminationDate, String? estBirthDate}) async {
    final db = await instance.database;
    return await db.update(
      'animals',
      {
        'is_pregnant': isPregnant ? 1 : 0,
        'insemination_date': inseminationDate,
        'est_birth_date': estBirthDate,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAnimal(int id) async {
    final db = await instance.database;
    return await db.delete('animals', where: 'id = ?', whereArgs: [id]);
  }

  // --- SÜT İŞLEMLERİ ---
  Future<List<MilkRecord>> getMilkRecords({int limit = 50}) async {
    final db = await instance.database;
    final maps = await db.query('milk_records', orderBy: 'date DESC, id DESC', limit: limit);
    return maps.map((e) => MilkRecord.fromMap(e)).toList();
  }

  Future<int> addMilkRecord(MilkRecord record) async {
    final db = await instance.database;
    return await db.insert('milk_records', record.toMap());
  }

  Future<int> deleteMilkRecord(int id) async {
    final db = await instance.database;
    return await db.delete('milk_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getTodayMilkSummary() async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final sabahRes = await db.rawQuery("SELECT SUM(liters) as total FROM milk_records WHERE date = ? AND session = 'Sabah'", [today]);
    final aksamRes = await db.rawQuery("SELECT SUM(liters) as total FROM milk_records WHERE date = ? AND session = 'Akşam'", [today]);

    final sabah = sabahRes.first['total'] != null ? (sabahRes.first['total'] as num).toDouble() : 0.0;
    final aksam = aksamRes.first['total'] != null ? (aksamRes.first['total'] as num).toDouble() : 0.0;

    return {
      'sabah': sabah,
      'aksam': aksam,
      'toplam': sabah + aksam,
    };
  }

  // --- KASA & FİNANS İŞLEMLERİ (GEÇMİŞ AYLAR DESTEKLİ) ---
  Future<List<FinanceRecord>> getFinanceRecords({String? monthFilter, int limit = 50}) async {
    final db = await instance.database;
    String? where;
    List<dynamic>? whereArgs;

    if (monthFilter != null && monthFilter.isNotEmpty) {
      where = 'date LIKE ?';
      whereArgs = ['$monthFilter%'];
    }

    final maps = await db.query('finance_records', where: where, whereArgs: whereArgs, orderBy: 'date DESC, id DESC', limit: limit);
    return maps.map((e) => FinanceRecord.fromMap(e)).toList();
  }

  Future<int> addFinanceRecord(FinanceRecord record) async {
    final db = await instance.database;
    return await db.insert('finance_records', record.toMap());
  }

  Future<int> deleteFinanceRecord(int id) async {
    final db = await instance.database;
    return await db.delete('finance_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getMonthlyFinanceSummary({String? monthFilter}) async {
    final db = await instance.database;
    final monthPrefix = monthFilter ?? DateFormat('yyyy-MM').format(DateTime.now());

    final incRes = await db.rawQuery("SELECT SUM(amount) as total FROM finance_records WHERE type = 'Gelir' AND date LIKE ?", ['$monthPrefix%']);
    final expRes = await db.rawQuery("SELECT SUM(amount) as total FROM finance_records WHERE type = 'Gider' AND date LIKE ?", ['$monthPrefix%']);

    final inc = incRes.first['total'] != null ? (incRes.first['total'] as num).toDouble() : 0.0;
    final exp = expRes.first['total'] != null ? (expRes.first['total'] as num).toDouble() : 0.0;

    return {
      'income': inc,
      'expense': exp,
      'profit': inc - exp,
    };
  }

  // --- GOOGLE DRIVE / JSON YEDEKLEME & GERİ YÜKLEME ---
  Future<String> exportBackupJson() async {
    final animals = await getAnimals();
    final milk = await getMilkRecords(limit: 500);
    final finance = await getFinanceRecords(limit: 500);

    final data = {
      'versiyon': '2.0',
      'yedek_tarihi': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      'hayvanlar': animals.map((a) => a.toMap()).toList(),
      'sut_kayitlari': milk.map((m) => m.toMap()).toList(),
      'kasa_kayitlari': finance.map((f) => f.toMap()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<bool> restoreFromBackupJson(String jsonString) async {
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final db = await instance.database;

      await db.transaction((txn) async {
        await txn.delete('animals');
        await txn.delete('milk_records');
        await txn.delete('finance_records');

        if (data['hayvanlar'] != null) {
          for (var item in data['hayvanlar']) {
            await txn.insert('animals', Map<String, dynamic>.from(item));
          }
        }
        if (data['sut_kayitlari'] != null) {
          for (var item in data['sut_kayitlari']) {
            await txn.insert('milk_records', Map<String, dynamic>.from(item));
          }
        }
        if (data['kasa_kayitlari'] != null) {
          for (var item in data['kasa_kayitlari']) {
            await txn.insert('finance_records', Map<String, dynamic>.from(item));
          }
        }
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
