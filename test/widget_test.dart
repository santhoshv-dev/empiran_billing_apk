import 'package:empiran/core/widgets/empiran_components.dart';
import 'package:empiran/data/remote/api_client.dart';
import 'package:empiran/features/auth/data/repositories/auth_repository.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:empiran/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createTestWidget() {
    final apiClient = ApiClient();
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: apiClient),
        RepositoryProvider<AuthRepository>(
          create: (_) => AuthRepository(apiClient: apiClient),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
            ),
          ),
        ],
        child: const MaterialApp(
          home: LoginPage(),
        ),
      ),
    );
  }

  testWidgets(
      'mobile sign-in has no registration and displays Billing App headline',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Billing App'), findsOneWidget);
    expect(find.textContaining('Create account'), findsNothing);
    expect(find.textContaining('Register'), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('empty credentials trigger validation errors', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final loginButton = find.byType(EmpiranButton);
    expect(loginButton, findsOneWidget);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Enter your username or email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
