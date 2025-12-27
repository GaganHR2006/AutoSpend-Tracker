import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

enum TransactionType { income, expense }

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get smsId => text().unique()();
  RealColumn get amount => real()();
  TextColumn get merchant => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('Uncategorized'))();
  IntColumn get type => intEnum<TransactionType>()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isManual => boolean()();
}

@DriftDatabase(tables: [Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Stream<List<Transaction>> watchAllTransactions() {
    return (select(transactions)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();
  }

  Stream<double> watchBalance() {

    
    // Custom query to subtract expense from income
    return customSelect(
      'SELECT (COALESCE((SELECT SUM(amount) FROM transactions WHERE type = 0), 0) - '
      'COALESCE((SELECT SUM(amount) FROM transactions WHERE type = 1), 0)) AS balance',
      readsFrom: {transactions}
    ).watch().map((rows) {
      if (rows.isEmpty) return 0.0;
      return rows.first.read<double>('balance');
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
