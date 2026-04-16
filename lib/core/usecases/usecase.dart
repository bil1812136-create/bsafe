/// Base contract for every use-case in the application.
///
/// [Output] – return type (wrap in Either / Result if you add dartz later).
/// [Params] – input parameter object; use [NoParams] when none are needed.
abstract class UseCase<Output, Params> {
  Future<Output> call(Params params);
}

/// Used as the [Params] type argument for use-cases that take no input.
class NoParams {
  const NoParams();
}
