import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/system_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize the entire system through bootstrap
    await SystemBootstrap.initialize();
    runApp(const AppRoot());
  } catch (e, st) {
    // STRICT BOOT FAILURE CONTRACT
    // ignore: avoid_print
    print('{"status":"BOOT_FAILED","reason":"$e","trace":"$st"}');
    rethrow;
  }
}
