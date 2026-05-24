import '../../data/models/debt_model.dart';

/// Sort debts by date, newest first.
List<DebtModel> sortDebtsByDateDesc(List<DebtModel> debts) {
  final sorted = List<DebtModel>.from(debts);
  sorted.sort((a, b) => b.date.compareTo(a.date));
  return sorted;
}

/// Unique person names from debts, most recently used first.
List<String> savedPersonNames(List<DebtModel> debts) {
  final latestByPerson = <String, DateTime>{};
  for (final debt in debts) {
    final key = debt.personName.trim().toLowerCase();
    if (key.isEmpty) continue;
    final existing = latestByPerson[key];
    if (existing == null || debt.date.isAfter(existing)) {
      latestByPerson[key] = debt.date;
    }
  }
  final displayNames = <String, String>{};
  for (final debt in debts) {
    final key = debt.personName.trim().toLowerCase();
    if (key.isNotEmpty) {
      displayNames[key] = debt.personName.trim();
    }
  }
  final names = displayNames.values.toList();
  names.sort((a, b) {
    final aKey = a.toLowerCase();
    final bKey = b.toLowerCase();
    return (latestByPerson[bKey] ?? DateTime(0))
        .compareTo(latestByPerson[aKey] ?? DateTime(0));
  });
  return names;
}

List<DebtModel> debtsForPerson(List<DebtModel> debts, String personName) {
  final key = personName.trim().toLowerCase();
  return sortDebtsByDateDesc(
    debts.where((d) => d.personName.trim().toLowerCase() == key).toList(),
  );
}

DebtModel? latestDebt(List<DebtModel> debts) {
  if (debts.isEmpty) return null;
  return sortDebtsByDateDesc(debts).first;
}
