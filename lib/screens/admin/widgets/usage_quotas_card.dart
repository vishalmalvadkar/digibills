import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../services/usage_stats_service.dart';
import 'usage_history_chart.dart';

class UsageQuotasCard extends StatefulWidget {
  const UsageQuotasCard({super.key});

  @override
  State<UsageQuotasCard> createState() => _UsageQuotasCardState();
}

class _UsageQuotasCardState extends State<UsageQuotasCard> {
  UsageStats? _currentUsage;
  List<UsageDataPoint>? _currentHistory;
  bool _isLoading = true;
  bool _isBannerVisible = true;
  UsageTimeRange _selectedRange = UsageTimeRange.daily;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    // We do NOT set isLoading to true here to avoid the "jump" to a spinner.
    // The previous data remains visible while new data fetches.
    
    try {
      final usage = await UsageStatsService().getEstimatedUsage(_selectedRange);
      List<UsageDataPoint> history = [];
      if (_selectedRange != UsageTimeRange.monthly && _selectedRange != UsageTimeRange.yearly) {
          // If daily, maybe we don't need history, or we fetch empty. 
          // The previous code only showed history for non-daily.
      } else {
        history = await UsageStatsService().getUsageHistory(_selectedRange);
      }

      if (mounted) {
        setState(() {
          _currentUsage = usage;
          _currentHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Handle error silently or show toast, don't break layout
        print("Error loading usage stats: $e");
      }
    }
  }

  void _onRangeChanged(UsageTimeRange range) {
    if (_selectedRange != range) {
      setState(() {
        _selectedRange = range;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Usage & Quotas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  if (_currentUsage != null)
                    _buildStatusBadge(_currentUsage!),
                ],
              ),
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    _buildTabButton('Today', UsageTimeRange.daily),
                    _buildTabButton('Month', UsageTimeRange.monthly),
                    _buildTabButton('Year', UsageTimeRange.yearly),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_isLoading && _currentUsage == null)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ))
          else if (_currentUsage != null)
             _buildContent(_currentUsage!),
        ],
      ),
    );
  }

  Widget _buildContent(UsageStats stats) {
    final isHighUsage = stats.status == 'WARNING' || stats.status == 'CRITICAL';
    
    return Column(
      children: [
        if (isHighUsage && _isBannerVisible)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quota Status: ${stats.status}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  onPressed: () => setState(() => _isBannerVisible = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                )
              ],
            ),
          ),

        // 1. Meter Bars directly inside this card now (Replacing UsageMeterCard logic)
        _buildMeterSection(stats),
        
        const SizedBox(height: 24),
        
        // 2. Mini Stats Row
        Row(
           mainAxisAlignment: MainAxisAlignment.spaceAround,
           children: [
              _buildMiniStat('Bills', stats.billsCount.toString()),
              _buildMiniStat('Expenses', stats.expensesCount.toString()),
              _buildMiniStat('Notifications', stats.notificationsCount.toString()),
           ],
        ),

        // 3. Chart (If applicable)
        if (_selectedRange != UsageTimeRange.daily && _currentHistory != null && _currentHistory!.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          Text(
            _selectedRange == UsageTimeRange.monthly ? 'Daily Trend' : 'Monthly Trend',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          // Use embeddable chart
          SizedBox(
            height: 200,
            child: UsageHistoryChart(points: _currentHistory!, range: _selectedRange, embed: true),
          ),
        ],
      ],
    );
  }

  Widget _buildMeterSection(UsageStats stats) {
    return Column(
      children: [
        _buildMeterRow('Database Size', stats.dbUsageMB, stats.dbLimitMB.toDouble(), Colors.green, isSize: true),
        const SizedBox(height: 16),
        _buildMeterRow('Asset Storage (Logos)', stats.assetUsageMB, stats.assetLimitMB.toDouble(), Colors.indigo, isSize: true),
        const SizedBox(height: 16),
        _buildMeterRow('Reads', stats.estimatedReads.toDouble(), stats.limitReads.toDouble(), Colors.blue),
        const SizedBox(height: 16),
        _buildMeterRow('Writes', stats.estimatedWrites.toDouble(), stats.limitWrites.toDouble(), Colors.purple),
      ],
    );
  }

  Widget _buildMeterRow(String label, double value, double limit, Color color, {bool isSize = false}) {
    double percent = limit > 0 ? value / limit : 0;
    if (percent > 1.0) percent = 1.0;
    
    // Formatting numbers
    String formatValue(double val) {
      if (isSize) {
        if (val >= 1024) return '${(val / 1024).toStringAsFixed(1)} GB';
        return '${val.toStringAsFixed(1)} MB';
      }
      if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
      if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}k';
      return val.toInt().toString();
    }
    
    Color barColor = color;
    if (percent > 0.8) barColor = AppColors.error;
    else if (percent > 0.6) barColor = Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
             Text('${formatValue(value)} / ${formatValue(limit)}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.grey[100],
            color: barColor,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
         Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
         Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
      ],
    );
  }

  Widget _buildTabButton(String text, UsageTimeRange range) {
    final isSelected = _selectedRange == range;
    return GestureDetector(
      onTap: () => _onRangeChanged(range),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected ? [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))
          ] : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textGrey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(UsageStats stats) {
    Color statusColor = AppColors.success;
    String statusText = 'SAFE';

    if (stats.status == 'CRITICAL') {
      statusColor = AppColors.error;
      statusText = 'CRITICAL';
    } else if (stats.status == 'WARNING') {
      statusColor = Colors.orange;
      statusText = 'WARNING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Text(
        statusText,
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
