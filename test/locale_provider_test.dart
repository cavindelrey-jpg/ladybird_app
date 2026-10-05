// test/locale_provider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academia_app/providers/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleProvider Language Settings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default language is system default with null locale (follows device)', () {
      final provider = LocaleProvider();
      expect(provider.language, AppLanguage.system);
      expect(provider.locale, isNull);
    });

    test('Selecting English updates locale to en and notifies listeners', () async {
      final provider = LocaleProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.setLanguage(AppLanguage.english);

      expect(provider.language, AppLanguage.english);
      expect(provider.locale, const Locale('en'));
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_language'), 'english');
    });

    test('Selecting French updates locale to fr and notifies listeners', () async {
      final provider = LocaleProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.setLanguage(AppLanguage.french);

      expect(provider.language, AppLanguage.french);
      expect(provider.locale, const Locale('fr'));
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_language'), 'french');
    });

    test('Selecting System Default resets locale to null (follows device)', () async {
      final provider = LocaleProvider();
      await provider.setLanguage(AppLanguage.french);
      expect(provider.locale, const Locale('fr'));

      await provider.setLanguage(AppLanguage.system);
      expect(provider.language, AppLanguage.system);
      expect(provider.locale, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_language'), 'system');
    });

    test('Restores English from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'english'});
      final provider = LocaleProvider();
      await provider.restoreFromPrefs();

      expect(provider.language, AppLanguage.english);
      expect(provider.locale, const Locale('en'));
    });

    test('Restores French from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'french'});
      final provider = LocaleProvider();
      await provider.restoreFromPrefs();

      expect(provider.language, AppLanguage.french);
      expect(provider.locale, const Locale('fr'));
    });

    test('System default locale resolution: follows device language', () {
      final provider = LocaleProvider();
      const supported = [Locale('en'), Locale('fr')];

      Locale resolve(Locale? deviceLocale) {
        if (provider.locale != null) return provider.locale!;
        if (deviceLocale != null) {
          for (final s in supported) {
            if (s.languageCode == deviceLocale.languageCode) return s;
          }
        }
        return supported.first;
      }

      // When device is French, system default resolves to French
      expect(resolve(const Locale('fr', 'FR')), const Locale('fr'));
      expect(resolve(const Locale('fr')), const Locale('fr'));

      // When device is English, system default resolves to English
      expect(resolve(const Locale('en', 'US')), const Locale('en'));
      expect(resolve(const Locale('en')), const Locale('en'));

      // When device is unsupported (e.g. de), system default falls back to first supported (en)
      expect(resolve(const Locale('de', 'DE')), const Locale('en'));
    });
  });
}
