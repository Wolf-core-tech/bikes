String? validatePassword(String password) {
  if (password.length < 8) {
    return 'Password must be at least 8 characters long.';
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Password must include at least one uppercase letter.';
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Password must include at least one number.';
  }
  return null;
}
