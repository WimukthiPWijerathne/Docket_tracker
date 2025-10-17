// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/loginScreen/login_page.dart';
import 'pages/assign.dart';
import 'pages/loginScreen/fetchUserAccess.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserAccess>(
      create: (_) => UserAccess(),
      child: MaterialApp(
        title: 'Docket Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF003366),
            onPrimary: Colors.white,
            secondary: Color(0xFFFFD700),
            onSecondary: Color(0xFF003366),
            error: Color(0xFFD32F2F),
            onError: Colors.white,
            surface: Color(0xFFF5F5F5),
            onSurface: Color(0xFF4A4A4A),
          ),
          scaffoldBackgroundColor: const Color(0xFFFFFFFF),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF003366),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          cardColor: const Color(0xFFF5F5F5),
          textTheme: ThemeData.light().textTheme.apply(
            bodyColor: const Color(0xFF4A4A4A),
            displayColor: const Color(0xFF4A4A4A),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF4A4A4A)),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: const Color(0xFF003366),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFFFFFFF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF003366)),
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIconColor: const Color(0xFF4A4A4A),
          ),
          chipTheme: const ChipThemeData(
            backgroundColor: Color(0xFFF5F5F5),
            selectedColor: Color(0xFFFFD700),
            secondarySelectedColor: Color(0xFF003366),
            labelStyle: TextStyle(color: Color(0xFF4A4A4A)),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            shape: StadiumBorder(),
          ),
        ),
        home: const LoginPage(),
        routes: {
          '/assign': (context) => const AssignPage(dockets: [], depot: 'All'),
        },
      ),
    );
  }
}
