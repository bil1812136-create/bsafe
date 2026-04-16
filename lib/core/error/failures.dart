abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No network connectivity']);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class ConfigurationFailure extends Failure {
  const ConfigurationFailure(super.message);
}

class AiAnalysisFailure extends Failure {
  const AiAnalysisFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'An unexpected error occurred']);
}
