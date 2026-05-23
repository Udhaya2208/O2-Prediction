import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:exif/exif.dart';

/// Result of analysing a captured tree image.
class TreeAnalysisResult {
  final double estimatedDiameterM;
  final double estimatedHeightM;
  final double crownDiameterM;
  final double leafDensityPercent;
  final double estimatedLeafAreaM2;
  final int estimatedAge;
  final double estimatedDistanceM;
  final String detectedType;
  final String speciesDisplayName;
  final double confidence;
  final List<String> allLabels;
  final double speciesO2Factor;
  final bool isTreeDetected;

  TreeAnalysisResult({
    required this.estimatedDiameterM,
    required this.estimatedHeightM,
    required this.crownDiameterM,
    required this.leafDensityPercent,
    required this.estimatedLeafAreaM2,
    required this.estimatedAge,
    required this.estimatedDistanceM,
    required this.detectedType,
    required this.speciesDisplayName,
    required this.confidence,
    required this.allLabels,
    required this.speciesO2Factor,
    required this.isTreeDetected,
  });
}

/// Comprehensive species database with real botanical data.
/// [heightMin, heightMax, typicalDBH, growthRateM/yr, o2KgPerYear, displayName]
class SpeciesProfile {
  final String key;
  final String displayName;
  final double heightMin;
  final double heightMax;
  final double typicalDBH;
  final double growthRate;
  final double o2KgPerYear; // kg O₂ produced per year by a mature tree
  final double leafAreaIndex; // LAI: ratio of leaf area to ground area

  const SpeciesProfile({
    required this.key,
    required this.displayName,
    required this.heightMin,
    required this.heightMax,
    required this.typicalDBH,
    required this.growthRate,
    required this.o2KgPerYear,
    required this.leafAreaIndex,
  });
}

/// Analyses a tree photo using ML Kit, pixel segmentation, and EXIF data.
/// Returns null if no tree is detected in the image.
class TreeAnalyzerService {
  // ─── Species Database ───
  // Real-world data: different species produce vastly different O₂
  static const List<SpeciesProfile> _speciesDB = [
    SpeciesProfile(key: 'oak', displayName: 'Oak Tree', heightMin: 10, heightMax: 25, typicalDBH: 0.60, growthRate: 0.35, o2KgPerYear: 118.0, leafAreaIndex: 5.0),
    SpeciesProfile(key: 'pine', displayName: 'Pine Tree', heightMin: 15, heightMax: 35, typicalDBH: 0.40, growthRate: 0.50, o2KgPerYear: 80.0, leafAreaIndex: 8.0),
    SpeciesProfile(key: 'palm', displayName: 'Palm Tree', heightMin: 5, heightMax: 20, typicalDBH: 0.35, growthRate: 0.30, o2KgPerYear: 45.0, leafAreaIndex: 3.0),
    SpeciesProfile(key: 'maple', displayName: 'Maple Tree', heightMin: 10, heightMax: 25, typicalDBH: 0.45, growthRate: 0.40, o2KgPerYear: 100.0, leafAreaIndex: 6.0),
    SpeciesProfile(key: 'birch', displayName: 'Birch Tree', heightMin: 10, heightMax: 20, typicalDBH: 0.30, growthRate: 0.45, o2KgPerYear: 85.0, leafAreaIndex: 4.5),
    SpeciesProfile(key: 'willow', displayName: 'Willow Tree', heightMin: 8, heightMax: 15, typicalDBH: 0.50, growthRate: 0.35, o2KgPerYear: 95.0, leafAreaIndex: 5.5),
    SpeciesProfile(key: 'banyan', displayName: 'Banyan Tree', heightMin: 15, heightMax: 30, typicalDBH: 1.00, growthRate: 0.25, o2KgPerYear: 150.0, leafAreaIndex: 7.0),
    SpeciesProfile(key: 'neem', displayName: 'Neem Tree', heightMin: 10, heightMax: 20, typicalDBH: 0.45, growthRate: 0.40, o2KgPerYear: 90.0, leafAreaIndex: 5.0),
    SpeciesProfile(key: 'mango', displayName: 'Mango Tree', heightMin: 8, heightMax: 25, typicalDBH: 0.50, growthRate: 0.35, o2KgPerYear: 105.0, leafAreaIndex: 6.0),
    SpeciesProfile(key: 'eucalyptus', displayName: 'Eucalyptus', heightMin: 15, heightMax: 40, typicalDBH: 0.40, growthRate: 0.80, o2KgPerYear: 110.0, leafAreaIndex: 3.5),
    SpeciesProfile(key: 'bamboo', displayName: 'Bamboo', heightMin: 5, heightMax: 20, typicalDBH: 0.10, growthRate: 1.50, o2KgPerYear: 35.0, leafAreaIndex: 4.0),
    SpeciesProfile(key: 'coconut', displayName: 'Coconut Palm', heightMin: 15, heightMax: 30, typicalDBH: 0.30, growthRate: 0.35, o2KgPerYear: 50.0, leafAreaIndex: 3.5),
    SpeciesProfile(key: 'teak', displayName: 'Teak Tree', heightMin: 15, heightMax: 30, typicalDBH: 0.50, growthRate: 0.45, o2KgPerYear: 95.0, leafAreaIndex: 5.0),
    SpeciesProfile(key: 'cedar', displayName: 'Cedar Tree', heightMin: 15, heightMax: 35, typicalDBH: 0.50, growthRate: 0.30, o2KgPerYear: 75.0, leafAreaIndex: 7.0),
    SpeciesProfile(key: 'spruce', displayName: 'Spruce Tree', heightMin: 15, heightMax: 30, typicalDBH: 0.35, growthRate: 0.35, o2KgPerYear: 70.0, leafAreaIndex: 8.0),
    SpeciesProfile(key: 'fig', displayName: 'Fig Tree', heightMin: 5, heightMax: 15, typicalDBH: 0.40, growthRate: 0.35, o2KgPerYear: 65.0, leafAreaIndex: 5.5),
    SpeciesProfile(key: 'flower', displayName: 'Flowering Plant', heightMin: 0.3, heightMax: 2.0, typicalDBH: 0.03, growthRate: 0.20, o2KgPerYear: 5.0, leafAreaIndex: 2.0),
    SpeciesProfile(key: 'shrub', displayName: 'Shrub', heightMin: 0.5, heightMax: 3.0, typicalDBH: 0.05, growthRate: 0.15, o2KgPerYear: 8.0, leafAreaIndex: 3.0),
    SpeciesProfile(key: 'hedge', displayName: 'Hedge Plant', heightMin: 0.5, heightMax: 3.0, typicalDBH: 0.04, growthRate: 0.20, o2KgPerYear: 7.0, leafAreaIndex: 4.0),
    SpeciesProfile(key: 'grass', displayName: 'Grass', heightMin: 0.1, heightMax: 1.0, typicalDBH: 0.01, growthRate: 0.50, o2KgPerYear: 2.0, leafAreaIndex: 2.0),
  ];

  // Default profile for unknown trees
  static const SpeciesProfile _defaultTree = SpeciesProfile(
    key: 'tree', displayName: 'Unknown Tree', heightMin: 5, heightMax: 20,
    typicalDBH: 0.30, growthRate: 0.35, o2KgPerYear: 100.0, leafAreaIndex: 5.0,
  );

  // Tree-related keywords to match ML Kit labels
  static const _treeKeywords = [
    'tree', 'plant', 'oak', 'pine', 'palm', 'maple', 'birch', 'willow',
    'wood', 'forest', 'vegetation', 'leaf', 'branch', 'trunk', 'nature',
    'hedge', 'shrub', 'garden', 'landscape', 'flower', 'grass', 'banyan',
    'neem', 'mango', 'eucalyptus', 'bamboo', 'coconut', 'teak', 'cedar',
    'spruce', 'fig', 'fir', 'cypress', 'flora', 'foliage', 'grove',
    'woodland', 'jungle', 'herb', 'botanical',
  ];

  // Minimum confidence required to consider image contains a tree
  static const double _minTreeConfidence = 0.25;

  /// Main analysis entry point — fully automatic.
  /// Returns null if the image cannot be processed.
  /// Returns result with isTreeDetected=false if no tree found.
  static Future<TreeAnalysisResult?> analyze(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();

      // Run ML Kit pipelines in parallel
      final results = await Future.wait([
        _runObjectDetection(imagePath),
        _runImageLabeling(imagePath),
        _readExifData(bytes),
      ]);

      final detectedObjects = results[0] as List<DetectedObject>;
      final labels = results[1] as List<ImageLabel>;
      final exifData = results[2] as Map<String, double>;

      // Collect all label texts
      final allLabels = labels.map((l) => l.label).toList();
      debugPrint('ML Kit labels: $allLabels');

      // ═══ TREE VALIDATION ═══
      // Check if this image actually contains a tree/plant
      final treeCheck = _validateTreePresence(labels);
      if (!treeCheck['isTree']!) {
        debugPrint('No tree detected in image. Labels: $allLabels');
        return TreeAnalysisResult(
          estimatedDiameterM: 0,
          estimatedHeightM: 0,
          crownDiameterM: 0,
          leafDensityPercent: 0,
          estimatedLeafAreaM2: 0,
          estimatedAge: 0,
          estimatedDistanceM: 0,
          detectedType: 'none',
          speciesDisplayName: 'Not a Tree',
          confidence: 0,
          allLabels: allLabels,
          speciesO2Factor: 0,
          isTreeDetected: false,
        );
      }

      // ═══ SPECIES IDENTIFICATION ═══
      final species = _identifySpecies(labels);
      final speciesProfile = species['profile'] as SpeciesProfile;
      final speciesConfidence = species['confidence'] as double;

      // Decode image for pixel analysis
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final imageWidth = image.width.toDouble();
      final imageHeight = image.height.toDouble();

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      codec.dispose();

      if (byteData == null) return null;

      // ═══ BOUNDING BOX DETECTION ═══
      final treeBBox = _findTreeBoundingBox(
        detectedObjects, imageWidth, imageHeight,
      );

      // ═══ GREEN PIXEL ANALYSIS ═══
      final greenAnalysis = _analyzeGreenPixels(
        byteData, imageWidth.toInt(), imageHeight.toInt(), treeBBox,
      );

      // Additional tree validation: check green pixel presence
      final greenPercent = greenAnalysis['greenPercent']!;
      if (greenPercent < 8.0 && speciesConfidence < 0.4) {
        debugPrint('Very low green content ($greenPercent%) and low confidence');
        return TreeAnalysisResult(
          estimatedDiameterM: 0,
          estimatedHeightM: 0,
          crownDiameterM: 0,
          leafDensityPercent: greenPercent,
          estimatedLeafAreaM2: 0,
          estimatedAge: 0,
          estimatedDistanceM: 0,
          detectedType: 'none',
          speciesDisplayName: 'Not a Tree',
          confidence: speciesConfidence,
          allLabels: allLabels,
          speciesO2Factor: 0,
          isTreeDetected: false,
        );
      }

      // ═══ TRUNK ANALYSIS ═══
      final trunkAnalysis = _analyzeTrunk(
        byteData, imageWidth.toInt(), imageHeight.toInt(), treeBBox,
      );

      // ═══ PROPORTION-BASED MEASUREMENT ═══
      // Instead of circular distance→height, use species + image proportions
      final focalLengthMM = exifData['focalLengthMM'] ?? 4.0;
      final sensorWidthMM = exifData['sensorWidthMM'] ?? 6.17;
      final sensorHeightMM = sensorWidthMM * 0.75;
      final focalLengthPx = (focalLengthMM * imageHeight) / sensorHeightMM;

      // Tree pixel proportions in image
      final treePxH = treeBBox['height']!;
      final treePxW = treeBBox['width']!;
      final treeFillRatio = treePxH / imageHeight; // 0.0 to 1.0

      // ═══ MATURITY ESTIMATION ═══
      // Use crown density + trunk width ratio to estimate maturity (0.0 to 1.0)
      final trunkRatio = trunkAnalysis['trunkWidthRatio']!;
      final crownDensityRatio = greenAnalysis['crownWidthRatio']!;
      // Thicker trunk + denser crown = more mature tree
      double maturity = ((trunkRatio / 0.15) * 0.4 + (crownDensityRatio / 0.9) * 0.4 + (greenPercent / 80.0) * 0.2).clamp(0.1, 1.0);

      // ═══ HEIGHT ESTIMATION ═══
      // Height = species range positioned by maturity
      // NOT derived from distance — breaks the circular dependency
      double estHeight = speciesProfile.heightMin +
          maturity * (speciesProfile.heightMax - speciesProfile.heightMin);

      // Additional variation from tree fill ratio:
      // A tree that fills less of the frame could be farther (shorter apparent)
      // but we use it as a minor adjustment, not the primary driver
      final fillAdjust = (treeFillRatio / 0.7).clamp(0.7, 1.3);
      estHeight *= fillAdjust;
      estHeight = estHeight.clamp(speciesProfile.heightMin * 0.5, speciesProfile.heightMax * 1.2);

      // ═══ DISTANCE FROM HEIGHT ═══
      // Now that we have a real height, compute distance
      // distance = (realHeight × focalLengthPx) / pixelHeight
      double estimatedDistance = (estHeight * focalLengthPx) / treePxH;
      estimatedDistance = estimatedDistance.clamp(1.0, 100.0);

      // ═══ CROWN & TRUNK DIAMETER ═══
      // Use distance + pixel widths to get real sizes
      final crownPxW = treePxW * crownDensityRatio;
      double crownDiameter = (crownPxW / focalLengthPx) * estimatedDistance;
      crownDiameter = crownDiameter.clamp(0.3, 25.0);

      final trunkPxW = treePxW * trunkRatio;
      double trunkDiameter = (trunkPxW / focalLengthPx) * estimatedDistance;
      // Also bound by species typical DBH
      trunkDiameter = trunkDiameter.clamp(
        speciesProfile.typicalDBH * 0.2,
        speciesProfile.typicalDBH * 3.0,
      );

      // ═══ LEAF AREA ═══
      final crownArea = pi * pow(crownDiameter / 2, 2);
      final leafArea = crownArea * (greenPercent / 100.0) * speciesProfile.leafAreaIndex;

      // ═══ AGE ESTIMATION ═══
      int estimatedAge = (estHeight / speciesProfile.growthRate).round().clamp(1, 500);

      // ═══ SPECIES O₂ FACTOR ═══
      // Ratio of this species' O₂ production to the default tree baseline (100 kg/yr)
      final o2Factor = speciesProfile.o2KgPerYear / 100.0;

      return TreeAnalysisResult(
        estimatedDiameterM: trunkDiameter,
        estimatedHeightM: estHeight,
        crownDiameterM: crownDiameter,
        leafDensityPercent: greenPercent,
        estimatedLeafAreaM2: leafArea,
        estimatedAge: estimatedAge,
        estimatedDistanceM: estimatedDistance,
        detectedType: speciesProfile.key,
        speciesDisplayName: speciesProfile.displayName,
        confidence: speciesConfidence,
        allLabels: allLabels,
        speciesO2Factor: o2Factor,
        isTreeDetected: true,
      );
    } catch (e) {
      debugPrint('TreeAnalyzerService error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // TREE VALIDATION — reject non-tree images
  // ═══════════════════════════════════════════════════════

  static Map<String, bool> _validateTreePresence(List<ImageLabel> labels) {
    double bestTreeScore = 0.0;

    for (final label in labels) {
      final lower = label.label.toLowerCase();
      for (final keyword in _treeKeywords) {
        if (lower.contains(keyword)) {
          if (label.confidence > bestTreeScore) {
            bestTreeScore = label.confidence;
          }
        }
      }
    }

    return {'isTree': bestTreeScore >= _minTreeConfidence};
  }

  // ═══════════════════════════════════════════════════════
  // SPECIES IDENTIFICATION with species-specific O₂ rates
  // ═══════════════════════════════════════════════════════

  static Map<String, dynamic> _identifySpecies(List<ImageLabel> labels) {
    SpeciesProfile bestMatch = _defaultTree;
    double bestConfidence = 0.0;

    for (final label in labels) {
      final lower = label.label.toLowerCase();
      for (final sp in _speciesDB) {
        if (lower.contains(sp.key) && label.confidence > bestConfidence) {
          bestConfidence = label.confidence;
          bestMatch = sp;
        }
      }
    }

    // If no specific species matched but tree was detected, use default
    if (bestConfidence == 0.0) {
      // Check if any tree-related keyword matched
      for (final label in labels) {
        final lower = label.label.toLowerCase();
        for (final keyword in _treeKeywords) {
          if (lower.contains(keyword) && label.confidence > bestConfidence) {
            bestConfidence = label.confidence;
          }
        }
      }
      if (bestConfidence > 0) {
        bestMatch = _defaultTree;
      }
    }

    return {'profile': bestMatch, 'confidence': bestConfidence};
  }

  // ═══════════════════════════════════════════════════════
  // ML Kit Object Detection
  // ═══════════════════════════════════════════════════════

  static Future<List<DetectedObject>> _runObjectDetection(
    String imagePath,
  ) async {
    try {
      final options = ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      );
      final detector = ObjectDetector(options: options);
      final inputImage = InputImage.fromFilePath(imagePath);
      final objects = await detector.processImage(inputImage);
      await detector.close();
      return objects;
    } catch (e) {
      debugPrint('Object detection error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════
  // ML Kit Image Labeling
  // ═══════════════════════════════════════════════════════

  static Future<List<ImageLabel>> _runImageLabeling(String imagePath) async {
    try {
      final labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.15),
      );
      final inputImage = InputImage.fromFilePath(imagePath);
      final labels = await labeler.processImage(inputImage);
      await labeler.close();
      return labels;
    } catch (e) {
      debugPrint('Image labeling error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════
  // EXIF Reader
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, double>> _readExifData(Uint8List bytes) async {
    try {
      final tags = await readExifFromBytes(bytes);
      double focalLength = 4.0;
      double sensorWidth = 6.17;

      if (tags.containsKey('EXIF FocalLength')) {
        final fl = tags['EXIF FocalLength'];
        if (fl != null) {
          final valStr = fl.toString();
          final parts = valStr.split('/');
          if (parts.length == 2) {
            final n = double.tryParse(parts[0].trim());
            final d = double.tryParse(parts[1].trim());
            if (n != null && d != null && d > 0) focalLength = n / d;
          } else {
            final p = double.tryParse(valStr.trim());
            if (p != null && p > 0) focalLength = p;
          }
        }
      }

      if (tags.containsKey('EXIF FocalLengthIn35mmFilm')) {
        final fl35 = tags['EXIF FocalLengthIn35mmFilm'];
        if (fl35 != null) {
          final fl35mm = double.tryParse(fl35.toString());
          if (fl35mm != null && fl35mm > 0 && focalLength > 0) {
            final cropFactor = fl35mm / focalLength;
            sensorWidth = 36.0 / cropFactor;
          }
        }
      }

      return {'focalLengthMM': focalLength, 'sensorWidthMM': sensorWidth};
    } catch (e) {
      debugPrint('EXIF read error: $e');
      return {'focalLengthMM': 4.0, 'sensorWidthMM': 6.17};
    }
  }

  // ═══════════════════════════════════════════════════════
  // Bounding Box Detection
  // ═══════════════════════════════════════════════════════

  static Map<String, double> _findTreeBoundingBox(
    List<DetectedObject> objects,
    double imageWidth,
    double imageHeight,
  ) {
    DetectedObject? bestObject;
    double bestArea = 0;

    for (final obj in objects) {
      final rect = obj.boundingBox;
      final area = rect.width * rect.height;
      if (area > bestArea) {
        bestArea = area;
        bestObject = obj;
      }
    }

    if (bestObject != null && bestArea > (imageWidth * imageHeight * 0.05)) {
      final rect = bestObject.boundingBox;
      return {
        'x': rect.left,
        'y': rect.top,
        'width': rect.width,
        'height': rect.height,
      };
    }

    // Fallback: center region, but NOT filling the whole frame
    return {
      'x': imageWidth * 0.20,
      'y': imageHeight * 0.10,
      'width': imageWidth * 0.60,
      'height': imageHeight * 0.75,
    };
  }

  // ═══════════════════════════════════════════════════════
  // Green Pixel Analysis
  // ═══════════════════════════════════════════════════════

  static Map<String, double> _analyzeGreenPixels(
    ByteData byteData,
    int imageWidth,
    int imageHeight,
    Map<String, double> bbox,
  ) {
    final bx = bbox['x']!.toInt().clamp(0, imageWidth - 1);
    final by = bbox['y']!.toInt().clamp(0, imageHeight - 1);
    final bw = bbox['width']!.toInt().clamp(1, imageWidth - bx);
    final bh = bbox['height']!.toInt().clamp(1, imageHeight - by);

    int greenPixels = 0;
    int totalPixels = 0;
    int crownGreenLeft = bx + bw;
    int crownGreenRight = bx;

    final crownEndY = by + (bh * 0.65).toInt();
    const step = 3;

    for (int y = by; y < by + bh; y += step) {
      for (int x = bx; x < bx + bw; x += step) {
        final offset = (y * imageWidth + x) * 4;
        if (offset + 3 >= byteData.lengthInBytes) continue;

        final r = byteData.getUint8(offset);
        final g = byteData.getUint8(offset + 1);
        final b = byteData.getUint8(offset + 2);

        totalPixels++;

        // Green detection: multiple shades
        // Light green: high G, moderate R, low B
        // Dark green: moderate G > R, G > B
        // Yellow-green: high R+G, low B
        final isGreen = (g > 50 && g > r * 0.8 && g > b * 1.05) ||
            (g > 80 && g > r * 0.7 && b < g * 0.9) ||
            (g > 60 && r > 50 && b < 60 && g >= r * 0.85);

        if (isGreen) {
          greenPixels++;
          if (y < crownEndY) {
            if (x < crownGreenLeft) crownGreenLeft = x;
            if (x > crownGreenRight) crownGreenRight = x;
          }
        }
      }
    }

    final greenPercent =
        totalPixels > 0 ? (greenPixels / totalPixels * 100.0) : 0.0;

    double crownWidthRatio = 0.6;
    if (crownGreenRight > crownGreenLeft) {
      crownWidthRatio =
          ((crownGreenRight - crownGreenLeft).toDouble() / bw).clamp(0.2, 1.0);
    }

    return {
      'greenPercent': greenPercent.clamp(0.0, 95.0),
      'crownWidthRatio': crownWidthRatio,
    };
  }

  // ═══════════════════════════════════════════════════════
  // Trunk Analysis
  // ═══════════════════════════════════════════════════════

  static Map<String, double> _analyzeTrunk(
    ByteData byteData,
    int imageWidth,
    int imageHeight,
    Map<String, double> bbox,
  ) {
    final bx = bbox['x']!.toInt().clamp(0, imageWidth - 1);
    final by = bbox['y']!.toInt().clamp(0, imageHeight - 1);
    final bw = bbox['width']!.toInt().clamp(1, imageWidth - bx);
    final bh = bbox['height']!.toInt().clamp(1, imageHeight - by);

    final trunkStartY = by + (bh * 0.70).toInt();
    final trunkEndY = (by + bh).clamp(0, imageHeight);

    int trunkPixels = 0;
    int totalTrunkRow = 0;
    int minTrunkX = bx + bw;
    int maxTrunkX = bx;

    const step = 2;

    for (int y = trunkStartY; y < trunkEndY; y += step) {
      for (int x = bx; x < bx + bw; x += step) {
        final offset = (y * imageWidth + x) * 4;
        if (offset + 3 >= byteData.lengthInBytes) continue;

        final r = byteData.getUint8(offset);
        final g = byteData.getUint8(offset + 1);
        final b = byteData.getUint8(offset + 2);

        totalTrunkRow++;

        // Brown bark: R > G > B, warm tones
        final isBrown = r > 40 && r > g && g > b && r < 200 && (r - b) > 15;
        // Dark bark: low intensity, not green dominant
        final isDarkBark = r < 120 && g < 100 && b < 90 &&
            !(g > r * 0.8 && g > b * 1.05);
        // Grey bark: similar R/G/B, medium intensity
        final isGreyBark = r > 60 && r < 180 && (r - g).abs() < 25 &&
            (g - b).abs() < 25 && !(g > 100 && g > r);

        if (isBrown || isDarkBark || isGreyBark) {
          trunkPixels++;
          if (x < minTrunkX) minTrunkX = x;
          if (x > maxTrunkX) maxTrunkX = x;
        }
      }
    }

    double trunkWidthRatio;
    if (trunkPixels > 5 && maxTrunkX > minTrunkX) {
      final trunkPixelSpan = (maxTrunkX - minTrunkX).toDouble();
      trunkWidthRatio = (trunkPixelSpan / bw).clamp(0.02, 0.30);
    } else {
      trunkWidthRatio = 0.05;
    }

    return {
      'trunkWidthRatio': trunkWidthRatio,
      'trunkDensity': totalTrunkRow > 0 ? (trunkPixels / totalTrunkRow) : 0.05,
    };
  }
}
