import 'dart:math' as math;

/// O2-Vision – Oxygen Production Calculator
///
/// Implements the scientific biomass-to-oxygen estimation pipeline.
class OxygenCalculator {
  /// Estimate above-ground biomass weight (kg).
  /// Formula: W = 0.25 × D² × H
  ///  - [diameterM] trunk diameter in meters at 1.3 m height (DBH)
  ///  - [heightM]   total tree height in meters
  static double aboveGroundWeight(double diameterM, double heightM) {
    return 0.25 * diameterM * diameterM * heightM;
  }

  /// Dry weight = 72.5 % of green weight.
  static double dryWeight(double greenWeight) {
    return greenWeight * 0.725;
  }

  /// Carbon stored = 50 % of dry weight.
  static double carbonStored(double dryWt) {
    return dryWt * 0.50;
  }

  /// Total O₂ released (kg) over the tree's life.
  /// Each kg of carbon fixed releases 2.667 kg O₂.
  static double oxygenReleased(double carbon) {
    return carbon * 2.667;
  }

  /// Convenience: run the full pipeline and return total O₂ in kg.
  static double totalOxygenKg(double diameterM, double heightM) {
    final w = aboveGroundWeight(diameterM, heightM);
    final dw = dryWeight(w);
    final c = carbonStored(dw);
    return oxygenReleased(c);
  }

  /// Estimated hourly O₂ production in **grams** during daylight.
  /// Assumes ~12 h daylight × 365 days = 4 380 daylight-hours/year.
  static double hourlyProductionGrams(double totalO2Kg) {
    const daylightHoursPerYear = 365 * 12;
    return (totalO2Kg / daylightHoursPerYear) * 1000.0;
  }

  /// Daily O₂ production in **kg**.
  /// Based on total lifetime O₂ ÷ estimated tree age in years ÷ 365 days.
  /// [treeAgeYears] defaults to 50 (typical mature tree).
  static double dailyO2Kg(double totalO2Kg, {int treeAgeYears = 50}) {
    if (treeAgeYears <= 0) return 0.0;
    return totalO2Kg / treeAgeYears / 365.0;
  }

  /// Number of humans this tree can supply with O₂ for one year.
  /// Average person consumes ~730 kg O₂ / year.
  static double humansSustained(double totalO2Kg) {
    return totalO2Kg / 730.0;
  }

  // ───── Environment modifiers ─────

  /// Temperature production factor.
  /// Returns 1.0 for optimal range (15–35 °C), 0.6 otherwise.
  static double temperatureFactor(double tempCelsius) {
    if (tempCelsius >= 15 && tempCelsius <= 35) return 1.0;
    return 0.6;
  }

  /// Returns `true` when ambient light is too low for photosynthesis.
  /// Threshold: < 50 lux → dormant / night mode.
  static bool isDormant(double lux) {
    return lux < 50;
  }

  /// Leaf area modifier: how much the actual leaf area boosts production
  /// compared to the baseline assumption of 50 m² leaf area.
  static double leafAreaModifier(double leafAreaM2) {
    const baselineLeafArea = 50.0; // m² — typical mature tree
    if (leafAreaM2 <= 0) return 1.0;
    return (leafAreaM2 / baselineLeafArea).clamp(0.1, 5.0);
  }

  /// Crown volume modifier: larger crowns capture more light.
  /// Based on crown diameter relative to a baseline of 6m crown diameter.
  static double crownVolumeModifier(double crownDiameterM) {
    const baselineCrown = 6.0; // meters
    if (crownDiameterM <= 0) return 1.0;
    return (crownDiameterM / baselineCrown).clamp(0.2, 4.0);
  }

  /// Leaf density modifier: denser foliage = slightly more production.
  static double leafDensityModifier(double leafDensityPercent) {
    // Baseline density ~50%
    if (leafDensityPercent <= 0) return 1.0;
    return (leafDensityPercent / 50.0).clamp(0.3, 2.0);
  }

  /// Full result bundle for the UI (original — kept for backward compat).
  static Map<String, dynamic> computeAll({
    required double diameterM,
    required double heightM,
    required double tempCelsius,
    required double lux,
    int treeAgeYears = 50,
  }) {
    final totalO2 = totalOxygenKg(diameterM, heightM);
    final dormant = isDormant(lux);
    final factor = temperatureFactor(tempCelsius);

    final adjustedHourly = dormant ? 0.0 : hourlyProductionGrams(totalO2) * factor;
    final daily = dailyO2Kg(totalO2, treeAgeYears: treeAgeYears);
    final adjustedDaily = dormant ? 0.0 : daily * factor;

    String status;
    if (dormant) {
      status = 'Dormant / Night Mode';
    } else if (factor == 1.0) {
      status = 'Optimal Production';
    } else {
      status = 'Reduced Production';
    }

    return {
      'totalO2Kg': totalO2,
      'hourlyO2Grams': adjustedHourly,
      'dailyO2Kg': adjustedDaily,
      'humansSustained': humansSustained(totalO2),
      'status': status,
      'isDormant': dormant,
      'tempFactor': factor,
    };
  }

  /// Enhanced result bundle that factors in leaf area, crown size, density,
  /// and species-specific O₂ production rate.
  static Map<String, dynamic> computeAllEnhanced({
    required double diameterM,
    required double heightM,
    required double tempCelsius,
    required double lux,
    required double leafAreaM2,
    required double crownDiameterM,
    required double leafDensityPercent,
    double speciesO2Factor = 1.0,
    int treeAgeYears = 50,
  }) {
    final baseTotal = totalOxygenKg(diameterM, heightM);
    final dormant = isDormant(lux);
    final tempFactor = temperatureFactor(tempCelsius);
    final leafFactor = leafAreaModifier(leafAreaM2);
    final crownFactor = crownVolumeModifier(crownDiameterM);
    final densityFactor = leafDensityModifier(leafDensityPercent);

    // Combined foliage modifier (geometric mean to avoid extreme values)
    final foliageMod = _geometricMean([leafFactor, crownFactor, densityFactor]);

    // Species O₂ factor: different trees produce different amounts
    // e.g., Oak=1.18, Pine=0.80, Palm=0.45, Banyan=1.50
    final speciesFactor = speciesO2Factor.clamp(0.1, 3.0);

    final enhancedTotal = baseTotal * foliageMod * speciesFactor;
    final combinedFactor = tempFactor * (dormant ? 0.0 : 1.0);

    final hourly = hourlyProductionGrams(enhancedTotal) * combinedFactor;
    final daily = dailyO2Kg(enhancedTotal, treeAgeYears: treeAgeYears) *
        combinedFactor;

    String status;
    if (dormant) {
      status = 'Dormant / Night Mode';
    } else if (tempFactor == 1.0 && foliageMod >= 0.8) {
      status = 'Optimal Production';
    } else if (foliageMod < 0.5) {
      status = 'Low Foliage — Reduced Production';
    } else if (tempFactor < 1.0) {
      status = 'Reduced Production (Temperature)';
    } else {
      status = 'Active Production';
    }

    return {
      'totalO2Kg': enhancedTotal,
      'hourlyO2Grams': hourly,
      'dailyO2Kg': daily,
      'humansSustained': humansSustained(enhancedTotal),
      'status': status,
      'isDormant': dormant,
      'tempFactor': tempFactor,
      'foliageModifier': foliageMod,
      'speciesO2Factor': speciesFactor,
    };
  }

  /// Geometric mean of a list of positive doubles.
  static double _geometricMean(List<double> values) {
    if (values.isEmpty) return 1.0;
    double product = 1.0;
    for (final v in values) {
      product *= v;
    }
    if (product <= 0) return 0.0;
    return math.pow(product, 1.0 / values.length).toDouble();
  }
}
