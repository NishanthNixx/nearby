import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseReady = await _initialiseFirebase();

  if (!firebaseReady) {
    // No Firebase configuration on this device. Rather than showing a dead
    // screen, fall back to the in-memory backend so the app is still usable.
    // Because both are real implementations of the same repository interfaces,
    // nothing above the data layer notices the difference.
    AppConfig.dataSource = DataSource.inMemory;
    debugPrint(
      'Nearby: Firebase unavailable — running against the in-memory backend. '
      'Run `flutterfire configure` to connect a Firebase project.',
    );
  }

  runApp(const ProviderScope(child: NearbyApp()));
}

/// Brings up Firebase and its reporting, returning whether it succeeded.
Future<bool> _initialiseFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (error) {
    return false;
  }

  try {
    final crashlytics = FirebaseCrashlytics.instance;

    // Route Flutter framework errors and uncaught async errors into
    // Crashlytics. Only in release: during development the console is more
    // useful than a remote dashboard.
    if (kReleaseMode) {
      FlutterError.onError = crashlytics.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (_) {
    // Reporting is not worth failing startup over.
  }

  return true;
}
