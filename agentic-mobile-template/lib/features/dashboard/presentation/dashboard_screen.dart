import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:welltrack/features/dashboard/presentation/dashboard_home_provider.dart';
import 'package:welltrack/features/dashboard/presentation/dashboard_provider.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/intelligence_insight_card.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/key_signals_grid.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/secondary_modules_list.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/shimmer_loading.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/today_summary_card.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/trends_preview_card.dart';

/// Main dashboard screen showing goal-adaptive metrics and module tiles.
class DashboardScreen extends ConsumerStatefulWidget {
  final String profileId;
  final String displayName;

  const DashboardScreen({
    super.key,
    required this.profileId,
    required this.displayName,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).initialize(widget.profileId);
      ref.read(dashboardHomeProvider.notifier).initialize(widget.profileId);
    });
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await Future.wait([
      ref.read(dashboardProvider.notifier).refresh(widget.profileId),
      ref.read(dashboardHomeProvider.notifier).refresh(widget.profileId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(dashboardHomeProvider);
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: homeState.isLoading
            ? const DashboardShimmer()
            : CustomScrollView(
                slivers: [
                  // Section 1: Today Summary
                  SliverToBoxAdapter(
                    child: TodaySummaryCard(
                      displayName: widget.displayName,
                      primaryMetric: homeState.primaryMetric,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Section 2: Key Signals Grid
                  SliverToBoxAdapter(
                    child: KeySignalsGrid(signals: homeState.keySignals),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Section 3: Intelligence Insight
                  SliverToBoxAdapter(
                    child: IntelligenceInsightCard(
                      insightText: homeState.insightText,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Section 4: Trends Preview
                  SliverToBoxAdapter(
                    child: TrendsPreviewCard(
                      trendData: homeState.trendData,
                      trendLabel: homeState.trendLabel,
                      trendDirection: homeState.trendDirection,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Section 5: Secondary Modules
                  SliverToBoxAdapter(
                    child: SecondaryModulesList(tiles: dashboard.tiles),
                  ),

                  // Bottom padding for scroll clearance
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _handleBottomNavTap(index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note_outlined),
            activeIcon: Icon(Icons.edit_note),
            label: 'Log',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Plan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _handleBottomNavTap(int index) {
    switch (index) {
      case 0:
        break; // Already on dashboard
      case 1:
        context.push('/daily-view');
      case 2:
        context.push('/insights');
      case 3:
        context.push('/profile');
    }
    // Reset index so Home tab stays highlighted when returning
    if (index != 0) {
      setState(() {
        _currentIndex = 0;
      });
    }
  }
}
