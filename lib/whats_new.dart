import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether to show „Co nowego” (What's new) once after an update to [release].
///
/// Shown when the app ran before with a version older than [release] (the previous `last_run_app_version`)
/// and now runs [release] or newer, and only once ([shownKey]). Not on a clean install (no previous version):
/// there is nothing to compare with, and a user of the old iOS app gets the welcome screen instead, whose
/// list of changes covers this release too.
class WhatsNew {
  /// The release the „Co nowego” sheet describes, major.minor. Change it together with the sheet's content.
  static const String release = '12.1';

  /// The last [release] whose sheet was shown. New key, see the list in CLAUDE.md.
  static const String shownKey = 'whatsNewShown';

  final Logger logger;

  WhatsNew({required this.logger});

  /// Returns true and records it when the sheet should be shown now. Never throws: a failure means no sheet.
  Future<bool> decide({required String? previousVersion, required String? currentVersion}) async {
    try {
      if (previousVersion == null || currentVersion == null) {
        return false;
      }
      if (_compare(previousVersion, release) >= 0 || _compare(currentVersion, release) < 0) {
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(shownKey) == release) {
        return false;
      }
      await prefs.setString(shownKey, release);
      logger.i('What\'s new: showing $release once after the update from $previousVersion.');
      return true;
    } catch (error, stackTrace) {
      logger.e('What\'s new: could not decide, not showing it.', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Compares the major.minor part of [version] (e.g. "12.0.0+7") with [majorMinor] (e.g. "12.1").
  static int _compare(String version, String majorMinor) {
    List<int> parts(String text) => text.split('+').first.split('.').take(2).map(int.parse).toList();
    final a = parts(version);
    final b = parts(majorMinor);
    return a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1]);
  }
}
