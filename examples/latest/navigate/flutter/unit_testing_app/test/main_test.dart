import 'package:flutter_test/flutter_test.dart';
import 'package:here_sdk/core.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'main_test.mocks.dart';

// Disclaimer: This test does not show a REAL unit test (although the test will get green).
// It just shows examples of how the HERE SDK can be accessed in a unit test scenario.
@GenerateMocks([Angle])
void main() {
  group('Angle', () {
    test('test Angle', () {
      var mockAngle = MockAngle();

      when(mockAngle.degrees).thenReturn(10.0);

      expect(mockAngle.degrees, 10.0);
      verify(mockAngle.degrees).called(1);
    });
  });
}
