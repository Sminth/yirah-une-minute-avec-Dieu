import 'package:flutter/material.dart';
import 'package:one_minute/app/app.dart';
import 'package:one_minute/controllers/home_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeController.preInitializeNotifications();
  runApp(const MyApp());
}
