/// Simple service-locator using Provider.
///
/// In main.dart, wrap the widget tree with [MultiProvider] and register
/// all providers here so features can access them via `context.read<T>()`.
///
/// If you later add get_it / injectable, replace the body of [getProviders]
/// with your DI module registrations.
library;

// This file acts as documentation for the DI strategy.
// Actual provider registrations live in lib/main.dart → BSafeApp.
//
// Provider graph:
//   ConnectivityProvider   (core)
//   LanguageProvider       (core)
//   NavigationProvider     (core)
//   ReportProvider         (defect_reporting)
//   InspectionProvider     (building_medical_record)
