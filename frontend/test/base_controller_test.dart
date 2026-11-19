import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/controllers/base_controller.dart';
import 'package:project/core/errors/app_exception.dart';

final class TestController extends BaseController {}

void main() {
  test('A stale result cannot replace the latest request', () async {
    final controller = TestController();
    addTearDown(controller.dispose);
    final oldResponse = Completer<String>();
    final values = <String>[];

    final oldRequest = controller.run(
      () => oldResponse.future,
      onSuccess: values.add,
    );
    expect(controller.state, ViewState.loading);

    await controller.run(() async => 'latest', onSuccess: values.add);
    oldResponse.complete('old');
    await oldRequest;

    expect(values, ['latest']);
    expect(controller.state, ViewState.success);
  });

  test('Typed failures expose a user-facing message', () async {
    final controller = TestController();
    addTearDown(controller.dispose);

    await controller.run<void>(
      () async => throw const ForbiddenException(),
      onSuccess: (_) => fail('A failed request cannot succeed'),
    );

    expect(controller.state, ViewState.error);
    expect(controller.errorMessage, 'Access denied.');
  });
}
