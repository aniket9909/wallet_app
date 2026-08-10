import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/settings_model.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/overlay_cache_service.dart';

// States
abstract class SettingsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final SettingsModel settings;

  SettingsLoaded(this.settings);

  @override
  List<Object?> get props => [settings];
}

class SettingsError extends SettingsState {
  final String message;

  SettingsError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _repository;
  StreamSubscription? _settingsSubscription;

  SettingsCubit(this._repository) : super(SettingsInitial());

  void loadSettings() {
    emit(SettingsLoading());
    _settingsSubscription?.cancel();
    _settingsSubscription = _repository.watchSettings().listen(
      (settings) {
        emit(SettingsLoaded(settings));
        OverlayCacheService.syncFromState(settings: settings);
      },
      onError: (error) {
        emit(SettingsError(error.toString()));
      },
    );
  }

  Future<void> updateSettings(SettingsModel settings) async {
    try {
      await _repository.updateSettings(settings);
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> toggleNotifications() async {
    try {
      final currentState = state;
      if (currentState is SettingsLoaded) {
        await _repository.toggleNotifications(currentState.settings);
      }
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> toggleDarkMode() async {
    try {
      final currentState = state;
      if (currentState is SettingsLoaded) {
        await _repository.toggleDarkMode(currentState.settings);
      }
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> addExpenseType(String type) async {
    try {
      final currentState = state;
      if (currentState is SettingsLoaded) {
        await _repository.addExpenseType(type, currentState.settings);
      }
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> removeExpenseType(String type) async {
    try {
      final currentState = state;
      if (currentState is SettingsLoaded) {
        await _repository.removeExpenseType(type, currentState.settings);
      }
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  void reset() {
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
    emit(SettingsInitial());
  }

  @override
  Future<void> close() {
    _settingsSubscription?.cancel();
    return super.close();
  }
}

