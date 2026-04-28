class UsernameAlreadyTakenException implements Exception {
  const UsernameAlreadyTakenException();

  @override
  String toString() => 'UsernameAlreadyTakenException';
}
