import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

enum TransactionType { income, expense }

// Lending type enum
enum LendingType { none, lent, returned }

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get smsId => text().unique()();
  RealColumn get amount => real()();
  TextColumn get merchant => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('Uncategorized'))();
  IntColumn get type => intEnum<TransactionType>()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isManual => boolean()();
  
  // ⭐ Lending Tracker fields
  BoolColumn get isLending => boolean().withDefault(const Constant(false))();
  IntColumn get lendingType => intEnum<LendingType>().withDefault(const Constant(0))();
  IntColumn get linkedLendingId => integer().nullable()();
}

@DriftDatabase(tables: [Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2; // ⭐ Bumped for lending columns

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add lending columns for existing databases
          await m.addColumn(transactions, transactions.isLending);
          await m.addColumn(transactions, transactions.lendingType);
          await m.addColumn(transactions, transactions.linkedLendingId);
        }
      },
    );
  }

  Stream<List<Transaction>> watchAllTransactions() {
    return (select(transactions)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();
  }

  Stream<double> watchBalance() {
    // Custom query to subtract expense from income, EXCLUDING lending transactions
    return customSelect(
      '''SELECT (
        COALESCE((SELECT SUM(amount) FROM transactions WHERE type = 0 AND is_lending = 0), 0) - 
        COALESCE((SELECT SUM(amount) FROM transactions WHERE type = 1 AND is_lending = 0), 0)
      ) AS balance''',
      readsFrom: {transactions}
    ).watch().map((rows) {
      if (rows.isEmpty) return 0.0;
      return rows.first.read<double>('balance');
    });
  }

  // ⭐ Watch lending summary (total lent, total returned)
  Stream<Map<String, double>> watchLendingSummary() {
    return customSelect(
      '''SELECT 
        COALESCE((SELECT SUM(amount) FROM transactions WHERE lending_type = 1), 0) AS lent,
        COALESCE((SELECT SUM(amount) FROM transactions WHERE lending_type = 2), 0) AS returned
      ''',
      readsFrom: {transactions}
    ).watch().map((rows) {
      if (rows.isEmpty) return {'lent': 0.0, 'returned': 0.0};
      return {
        'lent': rows.first.read<double>('lent'),
        'returned': rows.first.read<double>('returned'),
      };
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
