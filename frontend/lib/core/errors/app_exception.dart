sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Please sign in again.']);
}

final class ForbiddenException extends AppException {
  const ForbiddenException([super.message = 'Access denied.']);
}

final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'This item could not be found.']);
}

final class ValidationException extends AppException {
  const ValidationException(super.message);
}

final class ConflictException extends AppException {
  const ConflictException(super.message);
}

final class RateLimitException extends AppException {
  const RateLimitException([
    super.message = 'Too many attempts. Try again in a minute.',
  ]);
}

final class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Check your connection and try again.',
  ]);
}

final class ServerException extends AppException {
  const ServerException([super.message = 'Something went wrong. Try again.']);
}
