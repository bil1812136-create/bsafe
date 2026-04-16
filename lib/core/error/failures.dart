/// Base class for all domain-level failures (used instead of throwing raw exceptions
/// in Repository implementations).
abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Failure originating from a remote API or network call.
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Failure when the device has no network connectivity.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No network connectivity']);
}

/// Failure originating from local cache / database operations.
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Failure when required configuration (e.g. API keys) is missing.
class ConfigurationFailure extends Failure {
  const ConfigurationFailure(super.message);
}

/// Failure produced by the AI analysis service.
class AiAnalysisFailure extends Failure {
  const AiAnalysisFailure(super.message);
}

/// Generic / unexpected failure.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'An unexpected error occurred']);
}
