import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/oxygen_calculator.dart';
import '../services/light_sensor_service.dart';
import '../services/weather_service.dart';
import '../services/tree_analyzer_service.dart';

/// Central application state via ChangeNotifier.
class TreeState extends ChangeNotifier {
  final LightSensorService lightService = LightSensorService();

  // ─── Inputs ───
  double _diameter = 0.0;
  double _height = 0.0;

  // ─── Camera / Analysis ───
  String? _capturedImagePath;
  bool _analysisInProgress = false;
  String _detectedTreeType = '';
  String _speciesDisplayName = '';
  double _analysisConfidence = 0.0;
  List<String> _detectedLabels = [];
  String _analysisError = '';
  bool _isTreeDetected = true;

  // ─── Enhanced tree data ───
  double _crownDiameter = 0.0;
  double _leafDensity = 0.0;
  double _estimatedLeafArea = 0.0;
  int _estimatedAge = 0;
  double _estimatedDistance = 0.0;
  double _foliageModifier = 1.0;
  double _speciesO2Factor = 1.0;

  // ─── Sensor / Weather ───
  double _lux = 500.0;
  double _tempCelsius = 25.0;
  String _weatherDesc = 'Clear';
  String _cityName = '';
  int _humidity = 50;
  bool _weatherLoaded = false;
  bool _isDaytime = true;

  // ─── Calculated results ───
  double _totalO2Kg = 0.0;
  double _hourlyO2Grams = 0.0;
  double _dailyO2Kg = 0.0;
  double _humansSustained = 0.0;
  String _status = 'Waiting for scan…';
  bool _isDormant = false;
  double _tempFactor = 1.0;
  bool _hasResult = false;

  // ─── Getters ───
  double get diameter => _diameter;
  double get height => _height;
  double get lux => _lux;
  double get tempCelsius => _tempCelsius;
  String get weatherDesc => _weatherDesc;
  String get cityName => _cityName;
  int get humidity => _humidity;
  bool get weatherLoaded => _weatherLoaded;
  bool get isDaytime => _isDaytime;

  String? get capturedImagePath => _capturedImagePath;
  bool get analysisInProgress => _analysisInProgress;
  String get detectedTreeType => _detectedTreeType;
  String get speciesDisplayName => _speciesDisplayName;
  double get analysisConfidence => _analysisConfidence;
  List<String> get detectedLabels => _detectedLabels;
  String get analysisError => _analysisError;
  bool get isTreeDetected => _isTreeDetected;

  double get crownDiameter => _crownDiameter;
  double get leafDensity => _leafDensity;
  double get estimatedLeafArea => _estimatedLeafArea;
  int get estimatedAge => _estimatedAge;
  double get estimatedDistance => _estimatedDistance;
  double get foliageModifier => _foliageModifier;
  double get speciesO2Factor => _speciesO2Factor;

  double get totalO2Kg => _totalO2Kg;
  double get hourlyO2Grams => _hourlyO2Grams;
  double get dailyO2Kg => _dailyO2Kg;
  double get humansSustained => _humansSustained;
  String get status => _status;
  bool get isDormant => _isDormant;
  double get tempFactor => _tempFactor;
  bool get hasResult => _hasResult;

  // ─── Actions ───

  void initialize() {
    lightService.start();
    _isDaytime = LightSensorService.isDaytime();
    _lux = _isDaytime ? 500.0 : 10.0;
  }

  /// Full automatic analysis pipeline.
  /// Rejects non-tree images and shows error.
  Future<void> autoAnalyze(String imagePath) async {
    _capturedImagePath = imagePath;
    _analysisInProgress = true;
    _analysisError = '';
    _isTreeDetected = true;
    _hasResult = false;
    notifyListeners();

    try {
      // Full image analysis (automatic)
      final result = await TreeAnalyzerService.analyze(imagePath);

      if (result == null) {
        _analysisError = 'Could not process the image. Please try again.';
        _isTreeDetected = false;
        _hasResult = false;
        _analysisInProgress = false;
        notifyListeners();
        return;
      }

      // ═══ TREE VALIDATION ═══
      if (!result.isTreeDetected) {
        _isTreeDetected = false;
        _hasResult = false;
        _detectedLabels = result.allLabels;
        _analysisError = '🚫 No tree or plant detected in this image.\n'
            'Please capture a photo of an actual tree to get O₂ estimates.\n'
            'Detected: ${result.allLabels.take(5).join(", ")}';
        _analysisInProgress = false;
        notifyListeners();
        return;
      }

      // ═══ VALID TREE — populate data ═══
      _diameter = result.estimatedDiameterM;
      _height = result.estimatedHeightM;
      _crownDiameter = result.crownDiameterM;
      _leafDensity = result.leafDensityPercent;
      _estimatedLeafArea = result.estimatedLeafAreaM2;
      _estimatedAge = result.estimatedAge;
      _estimatedDistance = result.estimatedDistanceM;
      _detectedTreeType = result.detectedType;
      _speciesDisplayName = result.speciesDisplayName;
      _analysisConfidence = result.confidence;
      _detectedLabels = result.allLabels;
      _speciesO2Factor = result.speciesO2Factor;
      _isTreeDetected = true;

      // Auto-detect location and weather
      await _autoFetchWeather();

      // Day/night
      _isDaytime = LightSensorService.isDaytime();
      _lux = _isDaytime ? 500.0 : 10.0;

      // Enhanced calculation with species factor
      _runEnhancedCalculation();
    } catch (e) {
      _analysisError = 'Analysis failed: $e';
      debugPrint('autoAnalyze error: $e');
    } finally {
      _analysisInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _autoFetchWeather() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10));

      final data = await WeatherService.fetchWeather(
        position.latitude, position.longitude,
      );

      if (data != null) {
        _tempCelsius = data.tempCelsius;
        _weatherDesc = data.description;
        _cityName = data.cityName;
        _humidity = data.humidity;
        _weatherLoaded = true;
      }
    } catch (e) {
      debugPrint('Weather fetch error: $e');
    }
  }

  void _runEnhancedCalculation() {
    if (_diameter <= 0 || _height <= 0) return;

    final result = OxygenCalculator.computeAllEnhanced(
      diameterM: _diameter,
      heightM: _height,
      tempCelsius: _tempCelsius,
      lux: _lux,
      leafAreaM2: _estimatedLeafArea,
      crownDiameterM: _crownDiameter,
      leafDensityPercent: _leafDensity,
      speciesO2Factor: _speciesO2Factor,
      treeAgeYears: _estimatedAge > 0 ? _estimatedAge : 50,
    );

    _totalO2Kg = result['totalO2Kg'] as double;
    _hourlyO2Grams = result['hourlyO2Grams'] as double;
    _dailyO2Kg = result['dailyO2Kg'] as double;
    _humansSustained = result['humansSustained'] as double;
    _status = result['status'] as String;
    _isDormant = result['isDormant'] as bool;
    _tempFactor = result['tempFactor'] as double;
    _foliageModifier = result['foliageModifier'] as double;
    _hasResult = true;
  }

  void calculate() {
    _runEnhancedCalculation();
    notifyListeners();
  }

  void reset() {
    _diameter = 0.0;
    _height = 0.0;
    _capturedImagePath = null;
    _analysisInProgress = false;
    _detectedTreeType = '';
    _speciesDisplayName = '';
    _analysisConfidence = 0.0;
    _detectedLabels = [];
    _analysisError = '';
    _isTreeDetected = true;
    _crownDiameter = 0.0;
    _leafDensity = 0.0;
    _estimatedLeafArea = 0.0;
    _estimatedAge = 0;
    _estimatedDistance = 0.0;
    _foliageModifier = 1.0;
    _speciesO2Factor = 1.0;
    _totalO2Kg = 0.0;
    _hourlyO2Grams = 0.0;
    _dailyO2Kg = 0.0;
    _humansSustained = 0.0;
    _status = 'Waiting for scan…';
    _isDormant = false;
    _tempFactor = 1.0;
    _hasResult = false;
    _weatherLoaded = false;
    notifyListeners();
  }

  @override
  void dispose() {
    lightService.dispose();
    super.dispose();
  }
}
