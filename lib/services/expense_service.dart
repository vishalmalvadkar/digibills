import 'dart:async';
import '../models/expense_model.dart';
import 'api_client.dart';

class ExpenseService {
  final ApiClient _api = ApiClient();
  final List<ExpenseModel> _cachedExpenses = [];
  final StreamController<List<ExpenseModel>> _controller =
      StreamController<List<ExpenseModel>>.broadcast();
  bool _initialized = false;

  ExpenseService() {
    // Listen to real-time events from FastAPI WebSockets
    _api.realtimeEvents.listen((event) {
      if (event['table'] == 'expenses') {
        final action = event['action'];
        final data = event['data'] as Map<String, dynamic>;

        if (action == 'INSERT') {
          final exp = ExpenseModel.fromMap(data);
          _cachedExpenses.removeWhere((e) => e.id == exp.id);
          _cachedExpenses.add(exp);
          _sortAndEmit();
        } else if (action == 'UPDATE') {
          final exp = ExpenseModel.fromMap(data);
          final index = _cachedExpenses.indexWhere((e) => e.id == exp.id);
          if (index != -1) {
            _cachedExpenses[index] = exp;
          } else {
            _cachedExpenses.add(exp);
          }
          _sortAndEmit();
        } else if (action == 'DELETE') {
          final expId = data['id'];
          _cachedExpenses.removeWhere((e) => e.id == expId);
          _sortAndEmit();
        }
      }
    });
  }

  void _sortAndEmit() {
    _cachedExpenses.sort((a, b) => b.date.compareTo(a.date));
    _controller.add(List.unmodifiable(_cachedExpenses));
  }

  Future<void> _fetchInitial() async {
    try {
      final res = await _api.get('/api/v1/expenses');
      if (res is List) {
        _cachedExpenses.clear();
        for (var item in res) {
          _cachedExpenses.add(ExpenseModel.fromMap(Map<String, dynamic>.from(item)));
        }
        _sortAndEmit();
      }
    } catch (_) {
      _controller.add(List.unmodifiable(_cachedExpenses));
    }
  }

  Future<void> addExpense(ExpenseModel expense) async {
    final Map<String, dynamic> data = expense.toMap();
    if (expense.id.isEmpty) {
      data.remove('id');
    }
    await _api.post('/api/v1/expenses', body: data);
  }

  Future<void> deleteExpense(String id) async {
    await _api.delete('/api/v1/expenses/$id');
  }

  Stream<List<ExpenseModel>> streamExpenses() {
    if (!_initialized) {
      _initialized = true;
      _fetchInitial();
    } else {
      Future.microtask(() => _controller.add(List.unmodifiable(_cachedExpenses)));
    }
    return _controller.stream;
  }

  double calculateMonthlyTotal(List<ExpenseModel> expenses, DateTime month) {
    double total = 0;
    for (var expense in expenses) {
      if (expense.date.year == month.year && expense.date.month == month.month) {
        total += expense.amount;
      }
    }
    return total;
  }
}
