import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../state/tree_state.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Opens the device camera to capture a tree photo, then auto-analyzes.
  Future<void> _openCameraAndAnalyze() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 2560,
      );
      if (photo == null) return; // user cancelled camera

      if (!mounted) return;
      final state = context.read<TreeState>();
      // Fully automatic analysis — no manual input needed
      await state.autoAnalyze(photo.path);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Camera error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera error: $e', style: GoogleFonts.outfit()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TreeState>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1F0D), Color(0xFF0D2B12), Color(0xFF071A09)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _buildHeader(state),
                const SizedBox(height: 24),
                _buildImagePreview(state, size),
                const SizedBox(height: 20),
                _buildCaptureButton(state),
                const SizedBox(height: 16),
                if (state.analysisError.isNotEmpty) _buildError(state),
                if (state.hasResult && state.isTreeDetected) ...[
                  _buildTreeProfile(state),
                  const SizedBox(height: 12),
                  _buildTreeDimensions(state),
                  const SizedBox(height: 12),
                  _buildFoliageAnalysis(state),
                  const SizedBox(height: 12),
                  _buildWeatherInfo(state),
                  const SizedBox(height: 12),
                  _buildO2Summary(state),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(TreeState state) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: AppTheme.glassCard(opacity: 0.15),
          child: Icon(
            Icons.camera_alt_rounded,
            color: state.analysisInProgress
                ? AppTheme.warningAmber
                : AppTheme.primaryGreen,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tree Scanner',
                  style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite)),
              Text(
                state.analysisInProgress
                    ? 'Analyzing tree…'
                    : state.hasResult
                        ? 'Analysis complete!'
                        : 'Point camera at a tree & capture',
                style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textGrey),
              ),
            ],
          ),
        ),
        _buildStatusBadge(state),
      ],
    );
  }

  Widget _buildStatusBadge(TreeState state) {
    final isScanning = state.analysisInProgress;
    final hasResult = state.hasResult;

    Color color;
    String label;
    IconData icon;
    if (isScanning) {
      color = AppTheme.warningAmber;
      label = 'Scanning…';
      icon = Icons.radar_rounded;
    } else if (hasResult) {
      color = AppTheme.primaryGreen;
      label = 'Done';
      icon = Icons.check_circle_rounded;
    } else {
      color = AppTheme.textGrey;
      label = 'Ready';
      icon = Icons.circle_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildImagePreview(TreeState state, Size size) {
    final imagePath = state.capturedImagePath;
    final isAnalyzing = state.analysisInProgress;

    return GestureDetector(
      onTap: (!isAnalyzing && !state.hasResult) ? _openCameraAndAnalyze : null,
      child: Container(
        height: size.height * 0.40,
        decoration: AppTheme.glassCard(opacity: 0.08),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Show captured image or placeholder
            if (imagePath != null && !kIsWeb && File(imagePath).existsSync())
              Image.file(File(imagePath), fit: BoxFit.cover)
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Icon(Icons.park_rounded,
                              size: 72,
                              color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Tap to open camera',
                        style: GoogleFonts.outfit(
                            color: AppTheme.primaryGreen,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Point at any tree and capture',
                        style: GoogleFonts.outfit(
                            color: AppTheme.textGrey.withValues(alpha: 0.6),
                            fontSize: 12)),
                  ],
                ),
              ),
            // Analysis overlay
            if (isAnalyzing)
              Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryGreen,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Analyzing tree…',
                          style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _analysisStep(Icons.search_rounded, 'Detecting tree in image…'),
                      _analysisStep(Icons.eco_rounded, 'Analyzing leaves & crown…'),
                      _analysisStep(Icons.straighten, 'Measuring dimensions…'),
                      _analysisStep(Icons.social_distance, 'Estimating distance…'),
                      _analysisStep(Icons.thermostat, 'Fetching weather data…'),
                    ],
                  ),
                ),
              ),
            // Detection badge on captured image
            if (state.hasResult && !isAnalyzing)
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco_rounded,
                          color: AppTheme.primaryGreen, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${state.speciesDisplayName} • ${(state.analysisConfidence * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            // Distance badge
            if (state.hasResult && !isAnalyzing && state.estimatedDistance > 0)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.social_distance,
                          color: AppTheme.oxygenBlue, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${state.estimatedDistance.toStringAsFixed(1)}m away',
                        style: GoogleFonts.outfit(
                            color: AppTheme.oxygenBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _analysisStep(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primaryGreen.withValues(alpha: 0.7), size: 16),
          const SizedBox(width: 8),
          Text(text,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCaptureButton(TreeState state) {
    final isAnalyzing = state.analysisInProgress;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isAnalyzing ? 1.0 : 0.97 + (_pulseAnimation.value - 1.0) * 0.3,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: isAnalyzing
                  ? []
                  : [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: ElevatedButton(
              onPressed: isAnalyzing ? null : _openCameraAndAnalyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: isAnalyzing
                    ? AppTheme.primaryGreen.withValues(alpha: 0.4)
                    : AppTheme.primaryGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isAnalyzing)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.black54, strokeWidth: 2.5),
                    )
                  else
                    const Icon(Icons.camera_alt_rounded, size: 26),
                  const SizedBox(width: 12),
                  Text(
                    isAnalyzing
                        ? 'Auto-Analyzing…'
                        : state.hasResult
                            ? '📸 Scan Another Tree'
                            : '📸 Open Camera & Capture',
                    style: GoogleFonts.outfit(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Results Sections (shown after analysis) ───

  /// Tree Profile — type, confidence, and estimated age
  Widget _buildTreeProfile(TreeState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(opacity: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text('Tree Profile',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  state.speciesDisplayName,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentTeal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Confidence bar
          Row(
            children: [
              Text('AI Confidence',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textGrey)),
              const Spacer(),
              Text('${(state.analysisConfidence * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.analysisConfidence,
              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoTile(Icons.cake_rounded, 'Est. Age',
                  '~${state.estimatedAge} yr', AppTheme.warningAmber),
              const SizedBox(width: 10),
              _infoTile(Icons.social_distance, 'Distance',
                  '${state.estimatedDistance.toStringAsFixed(1)} m', AppTheme.oxygenBlue),
              const SizedBox(width: 10),
              _infoTile(Icons.eco_rounded, 'O₂ Rate',
                  '×${state.speciesO2Factor.toStringAsFixed(2)}', AppTheme.accentTeal),
            ],
          ),
          if (state.detectedLabels.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: state.detectedLabels.take(6).map((label) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.textGrey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.textGrey.withValues(alpha: 0.15)),
                  ),
                  child: Text(label,
                      style: GoogleFonts.outfit(
                          fontSize: 10, color: AppTheme.textGrey)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Tree Dimensions — height, diameter, crown
  Widget _buildTreeDimensions(TreeState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(opacity: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten_rounded,
                  color: AppTheme.oxygenBlue, size: 20),
              const SizedBox(width: 8),
              Text('Dimensions',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.oxygenBlue)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _infoTile(Icons.height, 'Height',
                  '${state.height.toStringAsFixed(1)} m', AppTheme.oxygenBlue),
              const SizedBox(width: 10),
              _infoTile(Icons.circle_outlined, 'Trunk Ø',
                  '${state.diameter.toStringAsFixed(2)} m', AppTheme.warningAmber),
              const SizedBox(width: 10),
              _infoTile(Icons.account_tree_rounded, 'Crown Ø',
                  '${state.crownDiameter.toStringAsFixed(1)} m',
                  AppTheme.primaryGreen),
            ],
          ),
        ],
      ),
    );
  }

  /// Foliage Analysis — leaf density, leaf area
  Widget _buildFoliageAnalysis(TreeState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(opacity: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.spa_rounded, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text('Foliage Analysis',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen)),
            ],
          ),
          const SizedBox(height: 12),
          // Leaf density bar
          Row(
            children: [
              Text('Leaf Density',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textGrey)),
              const Spacer(),
              Text('${state.leafDensity.toStringAsFixed(1)}%',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (state.leafDensity / 100.0).clamp(0.0, 1.0),
              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
              valueColor:
                  AlwaysStoppedAnimation<Color>(_leafDensityColor(state.leafDensity)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _infoTile(Icons.grass_rounded, 'Leaf Area',
                  '${state.estimatedLeafArea.toStringAsFixed(1)} m²',
                  AppTheme.primaryGreen),
              const SizedBox(width: 10),
              _infoTile(Icons.forest_rounded, 'Density',
                  _leafDensityLabel(state.leafDensity),
                  _leafDensityColor(state.leafDensity)),
            ],
          ),
        ],
      ),
    );
  }

  Color _leafDensityColor(double density) {
    if (density >= 60) return AppTheme.primaryGreen;
    if (density >= 35) return AppTheme.warningAmber;
    return Colors.red.shade400;
  }

  String _leafDensityLabel(double density) {
    if (density >= 60) return 'Dense';
    if (density >= 35) return 'Moderate';
    if (density >= 15) return 'Sparse';
    return 'Very Sparse';
  }

  Widget _buildWeatherInfo(TreeState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(opacity: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.warningAmber, size: 20),
              const SizedBox(width: 8),
              Text('Environment',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _infoTile(
                Icons.thermostat_rounded,
                'Temp',
                state.weatherLoaded
                    ? '${state.tempCelsius.toStringAsFixed(1)}°C'
                    : '25°C',
                AppTheme.warningAmber,
              ),
              const SizedBox(width: 10),
              _infoTile(
                state.isDaytime ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                'Light',
                state.isDaytime ? 'Day ☀️' : 'Night 🌙',
                state.isDaytime ? AppTheme.warningAmber : AppTheme.dormantPurple,
              ),
              const SizedBox(width: 10),
              _infoTile(
                Icons.water_drop_rounded,
                'Humidity',
                state.weatherLoaded ? '${state.humidity}%' : 'N/A',
                AppTheme.oxygenBlue,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _infoTile(
                Icons.cloud_rounded,
                'Weather',
                state.weatherLoaded ? state.weatherDesc : 'N/A',
                AppTheme.accentTeal,
              ),
              const SizedBox(width: 10),
              _infoTile(
                Icons.location_on_rounded,
                'Location',
                state.cityName.isNotEmpty ? state.cityName : 'N/A',
                AppTheme.dormantPurple,
              ),
              const SizedBox(width: 10),
              _infoTile(
                Icons.speed_rounded,
                'Temp ×',
                state.tempFactor.toStringAsFixed(1),
                state.tempFactor == 1.0
                    ? AppTheme.primaryGreen
                    : AppTheme.warningAmber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildO2Summary(TreeState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.12),
            AppTheme.oxygenBlue.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.spa_rounded, color: AppTheme.primaryGreen, size: 22),
              const SizedBox(width: 8),
              Text('Oxygen Production',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _o2Card(
                  'Daily O₂',
                  '${(state.dailyO2Kg * 1000).toStringAsFixed(2)} g',
                  'per day',
                  AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _o2Card(
                  'Hourly O₂',
                  '${state.hourlyO2Grams.toStringAsFixed(2)} g',
                  'per hour',
                  AppTheme.oxygenBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _o2Card(
                  'Total O₂',
                  '${state.totalO2Kg.toStringAsFixed(2)} kg',
                  'lifetime',
                  AppTheme.accentTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _o2Card(
                  'Humans',
                  state.humansSustained.toStringAsFixed(4),
                  'per year',
                  AppTheme.warningAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: (state.isDormant
                      ? AppTheme.dormantPurple
                      : AppTheme.primaryGreen)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  state.isDormant
                      ? Icons.nightlight_round
                      : Icons.check_circle_rounded,
                  color: state.isDormant
                      ? AppTheme.dormantPurple
                      : AppTheme.primaryGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  state.status,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: state.isDormant
                        ? AppTheme.dormantPurple
                        : AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _o2Card(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textGrey)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(unit,
              style: GoogleFonts.outfit(
                  fontSize: 10, color: AppTheme.textGrey.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textGrey)),
            const SizedBox(height: 2),
            Text(value,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(TreeState state) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(state.analysisError,
                style: GoogleFonts.outfit(
                    fontSize: 12, color: Colors.red.shade200)),
          ),
        ],
      ),
    );
  }
}
