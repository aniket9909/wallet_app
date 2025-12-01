import '../models/partial_transaction_model.dart';
import '../services/firebase_realtime_service.dart';

class PartialTransactionRepository {
  final FirebaseRealtimeService _service;

  PartialTransactionRepository(this._service);

  Stream<List<PartialTransaction>> watchPartialTransactions() {
    return _service.watchPartialTransactions();
  }

  Future<String> addPartialTransaction(PartialTransaction partial) async {
    return await _service.addPartialTransaction(partial);
  }

  Future<void> updatePartialTransaction(PartialTransaction partial) async {
    await _service.updatePartialTransaction(partial);
  }

  Future<void> deletePartialTransaction(String partialId) async {
    await _service.deletePartialTransaction(partialId);
  }

  Future<void> markAsSeen(String partialId) async {
    await _service.markPartialTransactionAsSeen(partialId);
  }
}

