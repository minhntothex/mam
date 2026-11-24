import 'package:flutter_test/flutter_test.dart';
import 'package:mam/l10n/mam_strings.dart';
import 'package:mam/widgets/sync_auth_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const en = MamStrings(AppLanguage.en);
  const vi = MamStrings(AppLanguage.vi);

  test('formatFriendlyAuthError maps AuthApiException codes to friendly EN & VI messages', () {
    const badCreds = AuthApiException(
      'Invalid login credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    );
    expect(formatFriendlyAuthError(badCreds, en), en.authErrInvalidCredentials);
    expect(formatFriendlyAuthError(badCreds, vi), vi.authErrInvalidCredentials);
    expect(formatFriendlyAuthError(badCreds, en), isNot(contains('AuthApiException')));

    const unconfirmed = AuthApiException(
      'Email not confirmed',
      statusCode: '400',
      code: 'email_not_confirmed',
    );
    expect(formatFriendlyAuthError(unconfirmed, vi), vi.authErrEmailNotConfirmed);

    const existing = AuthApiException(
      'User already registered',
      statusCode: '422',
      code: 'user_already_exists',
    );
    expect(formatFriendlyAuthError(existing, en), en.authErrUserExists);

    const rateLimited = AuthApiException(
      'Request rate limit reached',
      statusCode: '429',
      code: 'over_request_rate_limit',
    );
    expect(formatFriendlyAuthError(rateLimited, vi), vi.authErrRateLimited);

    expect(
      formatFriendlyAuthError(Exception('ClientException: Failed to fetch'), vi),
      vi.authErrNetwork,
    );
  });
}
