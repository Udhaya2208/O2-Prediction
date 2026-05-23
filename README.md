# 🌳 O₂-Vision – Tree Oxygen Monitor

A Flutter mobile app that estimates the oxygen production of a tree using camera measurements and environmental sensors.

## Features

- **AR Scanner**: Measure tree diameter (D) and height (H) via camera viewfinder (manual entry fallback)
- **Scientific Estimation Engine**: Biomass → Dry Weight → Carbon → O₂ pipeline
- **Light Sensor**: Detects day/night for dormant mode (0 O₂ at night)
- **Weather Integration**: OpenWeatherMap temperature check with optimal/reduced production
- **Dashboard**: Total O₂ stored, hourly production, humans sustained, formula breakdown

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run on connected device / emulator
flutter run

# Run unit tests
flutter test test/oxygen_calculator_test.dart
```

## Configuration

1. Get a free API key from [OpenWeatherMap](https://openweathermap.org/api)
2. Replace `YOUR_API_KEY_HERE` in `lib/services/weather_service.dart`

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── core/
│   ├── app_theme.dart                 # Dark-green nature theme
│   └── oxygen_calculator.dart         # Formula engine
├── services/
│   ├── ar_measurement_service.dart    # AR / manual measurement
│   ├── light_sensor_service.dart      # Ambient light sensor
│   └── weather_service.dart           # OpenWeatherMap API
├── state/
│   └── tree_state.dart                # ChangeNotifier state
├── screens/
│   ├── home_screen.dart               # Bottom nav shell
│   ├── scanner_screen.dart            # Camera / input view
│   └── dashboard_screen.dart          # Results dashboard
└── widgets/
    └── pulse_animated_widget.dart     # Shared animation widget
```

## The Formula

| Step | Formula |
|---|---|
| Above-ground weight | `W = 0.25 × D² × H` |
| Dry weight | `DW = W × 0.725` |
| Carbon stored | `C = DW × 0.50` |
| Oxygen released | `O₂ = C × 2.667` |
