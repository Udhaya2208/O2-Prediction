import 'package:flutter_test/flutter_test.dart';
import 'package:o2_vision/core/oxygen_calculator.dart';

void main() {
  group('OxygenCalculator', () {
    // ─── Test values ───
    // D = 0.30 m, H = 15.0 m
    // W = 0.25 × 0.30² × 15.0 = 0.25 × 0.09 × 15 = 0.3375 kg
    // DW = 0.3375 × 0.725 = 0.244688 kg
    // C = 0.244688 × 0.50 = 0.122344 kg
    // O₂ = 0.122344 × 2.667 = 0.326291 kg

    const d = 0.30;
    const h = 15.0;

    test('aboveGroundWeight returns correct biomass', () {
      final w = OxygenCalculator.aboveGroundWeight(d, h);
      expect(w, closeTo(0.3375, 0.0001));
    });

    test('dryWeight is 72.5% of green weight', () {
      final w = OxygenCalculator.aboveGroundWeight(d, h);
      final dw = OxygenCalculator.dryWeight(w);
      expect(dw, closeTo(0.2447, 0.001));
    });

    test('carbonStored is 50% of dry weight', () {
      final w = OxygenCalculator.aboveGroundWeight(d, h);
      final dw = OxygenCalculator.dryWeight(w);
      final c = OxygenCalculator.carbonStored(dw);
      expect(c, closeTo(0.1223, 0.001));
    });

    test('oxygenReleased uses 2.667 multiplier', () {
      final o2 = OxygenCalculator.totalOxygenKg(d, h);
      expect(o2, closeTo(0.3263, 0.001));
    });

    test('hourlyProductionGrams calculation', () {
      final o2 = OxygenCalculator.totalOxygenKg(d, h);
      final hourly = OxygenCalculator.hourlyProductionGrams(o2);
      // 0.3263 / 4380 * 1000 ≈ 0.0745 g/hr
      expect(hourly, closeTo(0.0745, 0.01));
    });

    test('humansSustained divides by 730', () {
      final o2 = OxygenCalculator.totalOxygenKg(d, h);
      final humans = OxygenCalculator.humansSustained(o2);
      expect(humans, closeTo(0.000447, 0.0001));
    });

    // ─── With a bigger tree ───
    test('large tree: D=0.5m, H=20m', () {
      // W = 0.25 × 0.25 × 20 = 1.25 kg
      final o2 = OxygenCalculator.totalOxygenKg(0.5, 20.0);
      // DW = 0.90625, C = 0.453125, O₂ = 1.2084
      expect(o2, closeTo(1.2084, 0.01));
    });
  });

  group('Environment modifiers', () {
    test('temperatureFactor is 1.0 within 15-35°C', () {
      expect(OxygenCalculator.temperatureFactor(25), equals(1.0));
      expect(OxygenCalculator.temperatureFactor(15), equals(1.0));
      expect(OxygenCalculator.temperatureFactor(35), equals(1.0));
    });

    test('temperatureFactor is 0.6 outside 15-35°C', () {
      expect(OxygenCalculator.temperatureFactor(5), equals(0.6));
      expect(OxygenCalculator.temperatureFactor(40), equals(0.6));
      expect(OxygenCalculator.temperatureFactor(-10), equals(0.6));
    });

    test('isDormant returns true when lux < 50', () {
      expect(OxygenCalculator.isDormant(10), isTrue);
      expect(OxygenCalculator.isDormant(49), isTrue);
    });

    test('isDormant returns false when lux >= 50', () {
      expect(OxygenCalculator.isDormant(50), isFalse);
      expect(OxygenCalculator.isDormant(500), isFalse);
    });
  });

  group('computeAll', () {
    test('returns Optimal Production in good conditions', () {
      final result = OxygenCalculator.computeAll(
        diameterM: 0.3,
        heightM: 15,
        tempCelsius: 25,
        lux: 500,
      );
      expect(result['status'], equals('Optimal Production'));
      expect(result['isDormant'], isFalse);
      expect(result['tempFactor'], equals(1.0));
      expect((result['hourlyO2Grams'] as double), greaterThan(0));
    });

    test('returns Dormant in low light', () {
      final result = OxygenCalculator.computeAll(
        diameterM: 0.3,
        heightM: 15,
        tempCelsius: 25,
        lux: 10,
      );
      expect(result['status'], equals('Dormant / Night Mode'));
      expect(result['isDormant'], isTrue);
      expect(result['hourlyO2Grams'], equals(0.0));
    });

    test('returns Reduced Production in cold weather', () {
      final result = OxygenCalculator.computeAll(
        diameterM: 0.3,
        heightM: 15,
        tempCelsius: 5,
        lux: 500,
      );
      expect(result['status'], equals('Reduced Production'));
      expect(result['tempFactor'], equals(0.6));
    });
  });
}
