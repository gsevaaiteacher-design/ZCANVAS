import 'package:flutter/material.dart';
import 'app/app.dart';
import 'dependency_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await DependencyRegistry.init();
    runApp(const AppRoot());
  } catch (e) {
    // STRICT BOOT FAILURE CONTRACT
    // ignore: avoid_print
    print('{"status":"BOOT_FAILED","reason":"$e"}');
  }
}