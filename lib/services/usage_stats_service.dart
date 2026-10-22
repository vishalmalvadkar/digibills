import 'package:supabase_flutter/supabase_flutter.dart';

enum UsageTimeRange { daily, monthly, yearly }

class UsageStats {
  final int totalClients;
  final int billsCount;
  final int expensesCount;
  final int notificationsCount;
  final int estimatedReads;
  final int estimatedWrites;
  final int limitReads;
  final int limitWrites;
  final double dbUsageMB;
  final int dbLimitMB;
  final double assetUsageMB;
  final int assetLimitMB;
  final String status; // 'SAFE', 'WARNING', 'CRITICAL'
  final UsageTimeRange range;

  UsageStats({
    required this.totalClients,
    required this.billsCount,
    required this.expensesCount,
    required this.notificationsCount,
    required this.estimatedReads,
    required this.estimatedWrites,
    required this.limitReads,
    required this.limitWrites,
    required this.dbUsageMB,
    required this.dbLimitMB,
    required this.assetUsageMB,
    required this.assetLimitMB,
    required this.status,
    required this.range,
  });
}

class UsageDataPoint {
  final String label; // "Mon", "Jan", "1", etc.
  final int reads;
  final int writes;

  UsageDataPoint(this.label, this.reads, this.writes);
}

class UsageStatsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Storage Limits (Supabase Free Tier)
  static const int _dbLimitMB = 512; // 500MB Database
  static const int _assetLimitMB = 1024; // 1GB File Storage (Images/Logos)

  // Limits (Supabase Egress/Request limits are different, but keeping legacy structure for UI)
  static const int _dailyLimitReads = 50000;
  static const int _dailyLimitWrites = 20000;
  
  static const int _monthlyLimitReads = 1500000; // 50k * 30
  static const int _monthlyLimitWrites = 600000; // 20k * 30

  static const int _yearlyLimitReads = 18000000; // 1.5M * 12
  static const int _yearlyLimitWrites = 7200000; // 600k * 12

  Future<UsageStats> getEstimatedUsage(UsageTimeRange range) async {
    final now = DateTime.now();
    DateTime startDate;
    int limitReads;
    int limitWrites;

    switch (range) {
      case UsageTimeRange.daily:
        startDate = DateTime(now.year, now.month, now.day);
        limitReads = _dailyLimitReads;
        limitWrites = _dailyLimitWrites;
        break;
      case UsageTimeRange.monthly:
        startDate = DateTime(now.year, now.month, 1);
        limitReads = _monthlyLimitReads;
        limitWrites = _monthlyLimitWrites;
        break;
      case UsageTimeRange.yearly:
        startDate = DateTime(now.year, 1, 1);
        limitReads = _yearlyLimitReads;
        limitWrites = _yearlyLimitWrites;
        break;
    }

    final startDateIso = startDate.toIso8601String();

    // 1. Fetch Real Activity Counts (Since startDate)
    
    // Clients
    final clientsCount = await _supabase
        .from('clients')
        .count(); 
    
    // Active Clients (Estimate based on total for now, optimized query would require filtering JSONB license which is complex in simple count)
    // For estimation, we'll assume 80% active or fetch if critical.
    final totalClients = clientsCount;
    final activeClients = (totalClients * 0.8).ceil(); // Approximation

    // Activity Counts
    final billsCount = await _supabase
        .from('bills')
        .select('bill_id')
        .gte('created_at', startDateIso)
        .count(CountOption.exact)
        .then((res) => res.count);

    final expensesCount = await _supabase
        .from('expenses')
        .select('id')
        .gte('date', startDateIso)
        .count(CountOption.exact)
        .then((res) => res.count);

    // Assuming notifications table exists
    int notificationsCount = 0;
    try {
      notificationsCount = await _supabase
          .from('notifications')
          .select('id')
          .gte('timestamp', startDateIso)
          .count(CountOption.exact)
          .then((res) => res.count);
    } catch (_) {
       // Table might not exist yet
    }

    // 1.5 Fetch ALL TIME counts for Storage Calculation (Global Size)
    final totalBills = await _supabase.from('bills').count();
    final totalExpenses = await _supabase.from('expenses').count();
    final totalNotifications = notificationsCount; // Approximate
    
    // Fetch Settings for Logo Sizes (Asset Usage)
    final settingsList = await _supabase.from('settings').select('logo_base64');
    double assetUsageMB = 0;
    for (var s in settingsList) {
      final logo = s['logo_base64']?.toString() ?? '';
      if (logo.isNotEmpty) {
        // Base64 to MB estimation: length * (3/4) / (1024 * 1024)
        assetUsageMB += (logo.length * 0.75) / (1024 * 1024);
      }
    }

    // Formula for pure DB (Rows/Metadata): 
    // Bills: 5kb, Expenses: 1kb, Clients: 2kb, Settings (Metadata): 2kb
    final double dbUsageMB = 5.0 + 
        (totalBills * 0.005) + 
        (totalExpenses * 0.001) + 
        (totalNotifications * 0.001) + 
        (totalClients * 0.002);

    // 2. Estimate Writes
    // Formula: Bills * 1.5 + Expenses + Notifications
    final estimatedWrites = (billsCount * 1.5).ceil() + expensesCount + notificationsCount;

    // 3. Estimate Reads (Dynamic Logic)
    // Base Load: ActiveClients * BaseReads * DaysElapsed
    // Activity Load: Writes * Multiplier (Viewing created items, lists)
    
    final daysElapsed = now.difference(startDate).inDays + 1;
    const baseReadsPerDay = 20; // Dashboard open, verify auth
    const readsPerWrite = 8; // Viewing list, detail, PDF download for each creation

    final baseLoad = activeClients * baseReadsPerDay * daysElapsed;
    final activityLoad = estimatedWrites * readsPerWrite;
    
    final estimatedReads = baseLoad + activityLoad;

    // 4. Determine Status relative to Range Limit
    String status = 'SAFE';
    final readUsagePercent = estimatedReads / limitReads;
    final writeUsagePercent = estimatedWrites / limitWrites;
    final dbPercent = dbUsageMB / _dbLimitMB;
    final assetPercent = assetUsageMB / _assetLimitMB;
    final maxUsage = [readUsagePercent, writeUsagePercent, dbPercent, assetPercent].reduce((a, b) => a > b ? a : b);

    if (maxUsage > 0.8) {
      status = 'CRITICAL';
    } else if (maxUsage > 0.4) {
      status = 'WARNING';
    }

    return UsageStats(
      totalClients: totalClients,
      billsCount: billsCount,
      expensesCount: expensesCount,
      notificationsCount: notificationsCount,
      estimatedReads: estimatedReads.toInt(),
      estimatedWrites: estimatedWrites,
      limitReads: limitReads,
      limitWrites: limitWrites,
      dbUsageMB: dbUsageMB,
      dbLimitMB: _dbLimitMB,
      assetUsageMB: assetUsageMB,
      assetLimitMB: _assetLimitMB,
      status: status,
      range: range,
    );
  }

  // Generate Mock History Data for Charts
  Future<List<UsageDataPoint>> getUsageHistory(UsageTimeRange range) async {
    // Return dummy data structure scaling with range limits to show UI visualization
    final List<UsageDataPoint> points = [];
    final now = DateTime.now();

    if (range == UsageTimeRange.daily) {
      // Hourly breakdown (Simulated)
      for (int i = 0; i <= now.hour; i+=4) {
        String label = '${i}h';
        points.add(UsageDataPoint(label, i * 100, i * 40));
      }
    } else if (range == UsageTimeRange.monthly) {
      // Daily breakdown
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      for (int i = 1; i <= daysInMonth; i+=5) { 
         // Simulation: Increasing trend
         points.add(UsageDataPoint('$i', i * 1500, i * 600)); 
      }
    } else {
      // Yearly breakdown
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      for (int i = 0; i < 12; i++) {
        if (i > now.month -1) break; 
        points.add(UsageDataPoint(months[i], 400000 + (i * 10000), 100000 + (i * 5000)));
      }
    }
    return points;
  }
}
