import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/savings_goal_model.dart';
import '../../data/repositories/savings_goal_repository.dart';

// States
abstract class SavingsGoalState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SavingsGoalInitial extends SavingsGoalState {}

class SavingsGoalLoading extends SavingsGoalState {}

class SavingsGoalLoaded extends SavingsGoalState {
  final List<SavingsGoalModel> goals;

  SavingsGoalLoaded(this.goals);

  @override
  List<Object?> get props => [goals];
}

class SavingsGoalError extends SavingsGoalState {
  final String message;

  SavingsGoalError(this.message);

  @override
  List<Object?> get props => [message];
}

class SavingsGoalOperationSuccess extends SavingsGoalState {
  final String message;

  SavingsGoalOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class SavingsGoalCubit extends Cubit<SavingsGoalState> {
  final SavingsGoalRepository _repository;
  StreamSubscription? _goalsSubscription;

  SavingsGoalCubit(this._repository) : super(SavingsGoalInitial());

  void loadGoals() {
    emit(SavingsGoalLoading());
    _goalsSubscription?.cancel();
    _goalsSubscription = _repository.watchSavingsGoals().listen(
      (goals) {
        emit(SavingsGoalLoaded(goals));
      },
      onError: (error) {
        emit(SavingsGoalError(error.toString()));
      },
    );
  }

  Future<void> addGoal(SavingsGoalModel goal) async {
    try {
      await _repository.addSavingsGoal(goal);
      // Don't emit success state - let the stream handle the update
      // The stream will automatically emit SavingsGoalLoaded with updated data
    } catch (e) {
      emit(SavingsGoalError(e.toString()));
      // After showing error, reload to get back to loaded state
      Future.delayed(const Duration(seconds: 2), () {
        if (state is SavingsGoalError) {
          loadGoals();
        }
      });
    }
  }

  Future<void> updateGoal(SavingsGoalModel goal) async {
    try {
      await _repository.updateSavingsGoal(goal);
      // Don't emit success state - let the stream handle the update
    } catch (e) {
      emit(SavingsGoalError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is SavingsGoalError) {
          loadGoals();
        }
      });
    }
  }

  Future<void> deleteGoal(String goalId) async {
    try {
      await _repository.deleteSavingsGoal(goalId);
      // Don't emit success state - let the stream handle the update
    } catch (e) {
      emit(SavingsGoalError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is SavingsGoalError) {
          loadGoals();
        }
      });
    }
  }

  Future<void> updateProgress(String goalId, double amount) async {
    try {
      final currentState = state;
      if (currentState is SavingsGoalLoaded) {
        await _repository.updateProgress(goalId, amount, currentState.goals);
        // Don't emit success state - let the stream handle the update
      }
    } catch (e) {
      emit(SavingsGoalError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is SavingsGoalError) {
          loadGoals();
        }
      });
    }
  }

  @override
  Future<void> close() {
    _goalsSubscription?.cancel();
    return super.close();
  }
}

