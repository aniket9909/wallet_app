import '../../core/database/local_app_database.dart';
import '../models/partial_transaction_model.dart';
import '../services/firebase_realtime_service.dart';

class PartialTransactionRepository {
  final FirebaseRealtimeService _service;
  final LocalAppDatabase _db = LocalAppDatabase.instance;

  PartialTransactionRepository(this._service);

  Stream<List<PartialTransaction>> watchPartialTransactions() async* {
    yield _parse(await _db.getEntityList(LocalAppDatabase.entityPartials));
    try {
      await for (final remote in _service.watchPartialTransactions()) {
        await _save(remote, synced: true);
        yield remote;
      }
    } catch (_) {
      yield _parse(await _db.getEntityList(LocalAppDatabase.entityPartials));
    }
  }

  Future<String> addPartialTransaction(PartialTransaction partial) async {
    final local =
        partial.id.isEmpty ? partial.copyWith(id: _db.newId()) : partial;
    final items = _parse(await _db.getEntityList(LocalAppDatabase.entityPartials));
    items.insert(0, local);
    await _save(items);
    try {
      await _service.addPartialTransaction(local);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityPartials,
        entityId: local.id,
        action: 'upsert',
        payload: {'id': local.id, ...local.toJson()},
      );
    }
    return local.id;
  }

  Future<void> updatePartialTransaction(PartialTransaction partial) async {
    final items = _parse(await _db.getEntityList(LocalAppDatabase.entityPartials));
    final index = items.indexWhere((p) => p.id == partial.id);
    if (index >= 0) {
      items[index] = partial;
    } else {
      items.insert(0, partial);
    }
    await _save(items);
    try {
      await _service.updatePartialTransaction(partial);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityPartials,
        entityId: partial.id,
        action: 'upsert',
        payload: {'id': partial.id, ...partial.toJson()},
      );
    }
  }

  Future<void> deletePartialTransaction(String partialId) async {
    final items = _parse(await _db.getEntityList(LocalAppDatabase.entityPartials));
    items.removeWhere((p) => p.id == partialId);
    await _save(items);
    try {
      await _service.deletePartialTransaction(partialId);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityPartials,
        entityId: partialId,
        action: 'delete',
      );
    }
  }

  Future<void> markAsSeen(String partialId) async {
    final items = _parse(await _db.getEntityList(LocalAppDatabase.entityPartials));
    final index = items.indexWhere((p) => p.id == partialId);
    if (index >= 0) {
      await updatePartialTransaction(items[index].copyWith(seen: true));
    } else {
      try {
        await _service.markPartialTransactionAsSeen(partialId);
      } catch (_) {}
    }
  }

  List<PartialTransaction> _parse(List<Map<String, dynamic>> items) {
    return items
        .map((e) => PartialTransaction.fromJson(e['id']?.toString() ?? '', e))
        .toList();
  }

  Future<void> _save(List<PartialTransaction> items, {bool synced = false}) {
    return _db.putEntityList(
      LocalAppDatabase.entityPartials,
      items.map((p) => {'id': p.id, ...p.toJson()}).toList(),
      synced: synced,
    );
  }
}
