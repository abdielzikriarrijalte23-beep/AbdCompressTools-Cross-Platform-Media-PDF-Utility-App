import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abdsukapdf/main.dart';
import 'package:abdsukapdf/services/theme_service.dart' as theme_service;

void main() {
  testWidgets('ABdCompressTools app launches', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeService = theme_service.ThemeService();
    await themeService.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider<theme_service.ThemeService>.value(
        value: themeService,
        child: const ABdSukaPDFApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
