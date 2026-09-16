import 'package:empiran/app_store.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'mobile sign-in has no registration and submits supplied credentials',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore();
    addTearDown(store.dispose);
    String? submittedUsername;
    String? submittedPassword;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(
            store: store,
            onLogin: (username, password) async {
              submittedUsername = username;
              submittedPassword = password;
            })));
    expect(find.text('Billing App'), findsOneWidget);
    expect(find.textContaining('Create account'), findsNothing);
    expect(find.textContaining('Register'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'santhosh');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(submittedUsername, 'santhosh');
    expect(submittedPassword, '123456');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty credentials are blocked in the dark theme',
      (tester) async {
    final store = AppStore();
    addTearDown(store.dispose);
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: LoginScreen(
            store: store,
            onLogin: (_, __) async {
              attempts++;
            })));
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(attempts, 0);
    expect(find.text('Enter your username or email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
