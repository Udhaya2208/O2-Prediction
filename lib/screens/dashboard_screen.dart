import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../state/tree_state.dart';
import '../widgets/pulse_animated_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _breatheController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TreeState>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: state.isDormant
              ? AppTheme.dormantGradient
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D1B0F), Color(0xFF071A09)],
                ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: state.hasResult
                ? _buildResults(state)
                : _buildEmptyState(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseAnimatedWidget(
            animation: _breatheAnimation,
            builder: (context, _) {
              return Opacity(
                opacity: _breatheAnimation.value,
                child: Icon(Icons.eco_rounded,
                    size: 80, color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
              );
            },
          ),
          const SizedBox(height: 20),
          Text('No Tree Scanned Yet',
              style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textWhite)),
          const SizedBox(height: 8),
          Text('Use the Scanner tab to capture a tree photo',
              style: GoogleFonts.outfit(
                  fontSize: 14, color: AppTheme.textGrey)),
        ],
      ),
    );
  }

  Widget _buildResults(TreeState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _buildDashboardHeader(state),
          const SizedBox(height: 20),
          if (state.capturedImagePath != null) _buildTreePhoto(state),
          if (state.capturedImagePath != null) const SizedBox(height: 16),
          _buildHeroCard(state),
          const SizedBox(height: 16),
          _buildDailyProductionCard(state),
          const SizedBox(height: 16),
          _buildStatsRow(state),
          const SizedBox(height: 16),
          _buildAutoDetectedInfo(state),
          const SizedBox(height: 16),
          _buildHumansCard(state),
          const SizedBox(height: 16),
          _buildFormulaBreakdown(state),
          const SizedBox(height: 16),
          _buildResetButton(state),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader(TreeState state) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: AppTheme.glassCard(opacity: 0.15),
          child: Icon(
            state.isDormant ? Icons.nightlight_round : Icons.dashboard_rounded,
            color: state.isDormant
                ? AppTheme.dormantPurple
                : AppTheme.primaryGreen,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('O₂ Dashboard',
                style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite)),
            Text(state.status,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: state.isDormant
                        ? AppTheme.dormantPurple
                        : (state.tempFactor == 1.0
                            ? AppTheme.primaryGreen
                            : AppTheme.warningAmber))),
          ],
        ),
      ],
    );
  }

  Widget _buildTreePhoto(TreeState state) {
    return Container(
      height: 140,
      decoration: AppTheme.glassCard(opacity: 0.08),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Thumbnail
          if (state.capturedImagePath != null &&
              File(state.capturedImagePath!).existsSync())
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: Image.file(
                File(state.capturedImagePath!),
                width: 120,
                height: 140,
                fit: BoxFit.cover,
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      state.detectedTreeType.toUpperCase(),
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentTeal),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Height: ${state.height.toStringAsFixed(1)} m',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppTheme.textWhite),
                  ),
                  Text(
                    'Diameter: ${state.diameter.toStringAsFixed(2)} m',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppTheme.textWhite),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confidence: ${(state.analysisConfidence * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppTheme.textGrey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(TreeState state) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: state.isDormant
            ? const LinearGradient(
                colors: [Color(0xFF4A148C), Color(0xFF311B92)])
            : AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (state.isDormant
                    ? AppTheme.dormantPurple
                    : AppTheme.primaryGreen)
                .withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          PulseAnimatedWidget(
            animation: _breatheAnimation,
            builder: (context, _) {
              return Transform.scale(
                scale: 0.95 + _breatheAnimation.value * 0.05,
                child: Icon(
                  state.isDormant ? Icons.nightlight : Icons.spa_rounded,
                  size: 44,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Total Oxygen Stored',
            style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            '${state.totalO2Kg.toStringAsFixed(2)} kg',
            style: GoogleFonts.outfit(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'of O₂ produced over this tree\'s life',
            style: GoogleFonts.outfit(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProductionCard(TreeState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.oxygenBlue.withValues(alpha: 0.15),
            AppTheme.primaryGreen.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.oxygenBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.oxygenBlue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.today_rounded,
                color: AppTheme.oxygenBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily O₂ Production',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textGrey,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  '${state.dailyO2Kg.toStringAsFixed(5)} kg/day',
                  style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.oxygenBlue),
                ),
                Text(
                  '${(state.dailyO2Kg * 1000).toStringAsFixed(2)} grams per day',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppTheme.textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(TreeState state) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.speed_rounded,
            label: 'Hourly Production',
            value: '${state.hourlyO2Grams.toStringAsFixed(2)} g/hr',
            color: state.isDormant ? AppTheme.dormantPurple : AppTheme.oxygenBlue,
            subtitle: state.isDormant ? 'Dormant' : 'Active',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.thermostat_rounded,
            label: 'Temperature',
            value: '${state.tempCelsius.toStringAsFixed(1)}°C',
            color: state.tempFactor == 1.0
                ? AppTheme.primaryGreen
                : AppTheme.warningAmber,
            subtitle:
                state.tempFactor == 1.0 ? 'Optimal (15-35°C)' : 'Reduced ×0.6',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCard(opacity: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 11, color: AppTheme.textGrey)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textWhite)),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(subtitle,
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoDetectedInfo(TreeState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(opacity: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: AppTheme.warningAmber, size: 18),
              const SizedBox(width: 8),
              Text('Auto-Detected',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _badge(
                icon: state.isDaytime
                    ? Icons.wb_sunny_rounded
                    : Icons.nightlight_round,
                label: state.isDaytime ? 'Daytime' : 'Night',
                value: state.isDaytime ? '☀️' : '🌙',
                color: state.isDaytime
                    ? AppTheme.warningAmber
                    : AppTheme.dormantPurple,
              ),
              const SizedBox(width: 10),
              _badge(
                icon: Icons.cloud_rounded,
                label: 'Weather',
                value: state.weatherLoaded
                    ? state.weatherDesc
                    : 'Default',
                color: AppTheme.oxygenBlue,
              ),
              const SizedBox(width: 10),
              _badge(
                icon: Icons.location_on_rounded,
                label: 'Location',
                value: state.cityName.isNotEmpty
                    ? state.cityName
                    : 'N/A',
                color: AppTheme.accentTeal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 10, color: AppTheme.textGrey)),
            const SizedBox(height: 2),
            Text(value,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildHumansCard(TreeState state) {
    final humans = state.humansSustained;
    final wholeHumans = humans.floor();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(opacity: 0.1),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded,
                  color: AppTheme.accentTeal, size: 22),
              const SizedBox(width: 8),
              Text('Humans Sustained',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(min(wholeHumans, 8), (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.person_rounded,
                      color: AppTheme.accentTeal.withValues(alpha: 0.8), size: 28),
                );
              }),
              if (wholeHumans > 8)
                Text(' +${wholeHumans - 8}',
                    style: GoogleFonts.outfit(
                        color: AppTheme.accentTeal, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.outfit(fontSize: 15, color: AppTheme.textGrey),
              children: [
                const TextSpan(text: 'This tree provides oxygen for '),
                TextSpan(
                  text: humans.toStringAsFixed(4),
                  style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentTeal),
                ),
                const TextSpan(text: '\nhumans per year'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '(Based on avg. 730 kg O₂/year per person)',
            style: GoogleFonts.outfit(
                fontSize: 11, color: AppTheme.textGrey.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaBreakdown(TreeState state) {
    final d = state.diameter;
    final h = state.height;
    final w = 0.25 * d * d * h;
    final dw = w * 0.725;
    final c = dw * 0.50;
    final o2 = c * 2.667;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(opacity: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.functions_rounded,
                  color: AppTheme.oxygenBlue, size: 20),
              const SizedBox(width: 8),
              Text('Formula Breakdown',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite)),
            ],
          ),
          const SizedBox(height: 14),
          _formulaRow('1. Above-ground weight',
              'W = 0.25 × ${d.toStringAsFixed(2)}² × ${h.toStringAsFixed(1)}',
              '${w.toStringAsFixed(3)} kg'),
          _formulaRow('2. Dry weight',
              'DW = ${w.toStringAsFixed(3)} × 0.725',
              '${dw.toStringAsFixed(3)} kg'),
          _formulaRow('3. Carbon stored',
              'C = ${dw.toStringAsFixed(3)} × 0.50',
              '${c.toStringAsFixed(3)} kg'),
          _formulaRow('4. Oxygen released',
              'O₂ = ${c.toStringAsFixed(3)} × 2.667',
              '${o2.toStringAsFixed(3)} kg'),
        ],
      ),
    );
  }

  Widget _formulaRow(String step, String formula, String result) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step,
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppTheme.textGrey,
                        fontWeight: FontWeight.w500)),
                Text(formula,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.oxygenBlue.withValues(alpha: 0.8))),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(result,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton(TreeState state) {
    return Center(
      child: TextButton.icon(
        onPressed: () => state.reset(),
        icon: Icon(Icons.refresh_rounded,
            color: AppTheme.textGrey.withValues(alpha: 0.6), size: 18),
        label: Text('Scan a new tree',
            style: GoogleFonts.outfit(
                color: AppTheme.textGrey.withValues(alpha: 0.6),
                fontSize: 13)),
      ),
    );
  }
}
