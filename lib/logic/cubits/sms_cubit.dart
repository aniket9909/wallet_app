import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/sms_repository.dart';
import '../../data/models/sms_message_model.dart';

// States
abstract class SmsState extends Equatable {
  const SmsState();

  @override
  List<Object?> get props => [];
}

class SmsInitial extends SmsState {}

class SmsLoading extends SmsState {}

class SmsLoaded extends SmsState {
  final List<SmsMessageModel> messages;
  final int unreadCount;

  const SmsLoaded({
    required this.messages,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [messages, unreadCount];
}

class SmsError extends SmsState {
  final String message;

  const SmsError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class SmsCubit extends Cubit<SmsState> {
  final SmsRepository _repository;

  SmsCubit(this._repository) : super(SmsInitial());

  Future<void> loadAllSms() async {
    emit(SmsLoading());
    try {
      final messages = await _repository.getAllSms();
      final unreadCount = await _repository.getUnreadCount();
      emit(SmsLoaded(messages: messages, unreadCount: unreadCount));
    } catch (e) {
      emit(SmsError(e.toString()));
    }
  }

  Future<void> saveSms(SmsMessageModel sms) async {
    try {
      await _repository.saveSms(sms);
      // Reload messages after saving
      await loadAllSms();
    } catch (e) {
      emit(SmsError(e.toString()));
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await _repository.markAsRead(id);
      await loadAllSms();
    } catch (e) {
      emit(SmsError(e.toString()));
    }
  }

  Future<void> deleteSms(int id) async {
    try {
      await _repository.deleteSms(id);
      await loadAllSms();
    } catch (e) {
      emit(SmsError(e.toString()));
    }
  }

  Future<void> deleteAllSms() async {
    try {
      await _repository.deleteAllSms();
      await loadAllSms();
    } catch (e) {
      emit(SmsError(e.toString()));
    }
  }

  Future<void> markAsCorrect(int id) async {
    try {
      await _repository.updateSmsStatus(id, SmsStatus.correct);
      final sms = await _repository.getSmsById(id);
      if (sms != null) {
        await _repository.updateSmsInFirebase(sms);
      }
      await loadAllSms();
    } catch (e) {
      emit(SmsError(e.toString()));
    }
  }

  Future<void> markAsWrong(int id) async {
    try {
      final sms = await _repository.getSmsById(id);
      if (sms != null) {
        await _repository.updateSmsStatus(id, SmsStatus.wrong);
        await _repository.updateSmsInFirebase(sms.copyWith(status: SmsStatus.wrong));
        // Delete from local storage
        await _repository.deleteSms(id);
        await _repository.deleteSmsFromFirebase(id.toString());
      }
      await loadAllSms();
    } catch (e) {
      emit(SmsError(e.toString()));
    }
  }

  Future<void> markAsDecline(int id) async {
    try {
      final sms = await _repository.getSmsById(id);
      if (sms != null) {
        await _repository.updateSmsStatus(id, SmsStatus.decline);
        await _repository.updateSmsInFirebase(sms.copyWith(status: SmsStatus.decline));
        // Delete from local storage
        await _repository.deleteSms(id);
        await _repository.deleteSmsFromFirebase(id.toString());
      }
      await loadAllSms();
    } catch (e) {
      emit(SmsError(e.toString()));
    }
  }
}

