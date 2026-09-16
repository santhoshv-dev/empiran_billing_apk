import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:empiran/data/remote/api_client.dart';
import 'package:empiran/password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString('{"message":"Request received"}', 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
      'forgot password sends registered email to API and displays response',
      (tester) async {
    final adapter = RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
      ..httpClientAdapter = adapter;
    await tester.pumpWidget(MaterialApp(
        home: PasswordScreen(
            api: ApiClient(dio: dio), action: PasswordAction.forgot)));
    await tester.enterText(find.byType(TextFormField), 'person@example.test');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(adapter.request?.path, 'auth/forgot-password');
    expect(adapter.request?.data, {'email': 'person@example.test'});
    expect(find.text('Request received'), findsOneWidget);
  });

  testWidgets('mismatched reset confirmation prevents API submission',
      (tester) async {
    final adapter = RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    await tester.pumpWidget(MaterialApp(
        home: PasswordScreen(
            api: ApiClient(dio: dio),
            action: PasswordAction.reset,
            token: 'token')));
    await tester.enterText(find.byType(TextFormField).at(0), 'long-password');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'different-password');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Passwords must match.'), findsOneWidget);
    expect(adapter.request, isNull);
  });
}
