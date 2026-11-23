import 'package:flutter_test/flutter_test.dart';
import 'package:mam/services/supabase_config.dart';

void main() {
  group('SupabaseConfig.normalizeUrl', () {
    test('strips /rest/v1/ path to project origin', () {
      expect(
        SupabaseConfig.normalizeUrl(
          'https://jzpcxkarpyldptshkykn.supabase.co/rest/v1/',
        ),
        'https://jzpcxkarpyldptshkykn.supabase.co',
      );
    });

    test('strips /auth/v1 and trailing slashes', () {
      expect(
        SupabaseConfig.normalizeUrl('https://demo.supabase.co/auth/v1/'),
        'https://demo.supabase.co',
      );
      expect(
        SupabaseConfig.normalizeUrl('  https://demo.supabase.co/  '),
        'https://demo.supabase.co',
      );
    });

    test('preserves clean origin and localhost ports', () {
      expect(
        SupabaseConfig.normalizeUrl('https://demo.supabase.co'),
        'https://demo.supabase.co',
      );
      expect(
        SupabaseConfig.normalizeUrl('http://127.0.0.1:54321/rest/v1'),
        'http://127.0.0.1:54321',
      );
    });

    test('returns empty string for blank input', () {
      expect(SupabaseConfig.normalizeUrl(''), '');
      expect(SupabaseConfig.normalizeUrl('   '), '');
    });
  });
}
