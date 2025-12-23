import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_db.g.dart';

class Logs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()();
  TextColumn get kind => text()();
  TextColumn get subtype => text().nullable()();
  IntColumn get minutes => integer().nullable()();
  TextColumn get purchaseType => text().nullable()();
  IntColumn get expGained => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [Logs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<Log>> getAllLogs() => select(logs).get();
  Stream<List<Log>> watchAllLogs() => select(logs).watch();

  Future<void> insertLog(LogsCompanion entry) => into(logs).insert(entry);

  Future<void> deleteLog(int id) =>
      (delete(logs)..where((tbl) => tbl.id.equals(id))).go();

  // ✅ 커스텀 행동 삭제 시 관련 로그 정리용
  Future<void> deleteLogsByAction(String actionName) =>
      (delete(logs)..where((t) => t.action.equals(actionName))).go();

  // ✅ (추가) 기록 수정용 — id 기준 업데이트
  Future<void> updateLogById(int id, LogsCompanion entry) async {
    await (update(logs)..where((t) => t.id.equals(id))).write(entry);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'haedo.sqlite'));
    return NativeDatabase(file);
  });
}
