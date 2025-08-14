import 'package:flutter/material.dart';
import 'package:one_minute/views/home_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final bool v = prefs.getBool('dark_mode') ?? false;
    if (mounted) setState(() => _darkMode = v);
  }

  Future<void> _toggleTheme() async {
    setState(() => _darkMode = !_darkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData light = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
    );
    final ThemeData dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0E1217),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'One Minute',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeView(onToggleTheme: _toggleTheme),
    );
  }
}
