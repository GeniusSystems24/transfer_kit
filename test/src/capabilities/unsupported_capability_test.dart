import 'package:flutter_test/flutter_test.dart';
import 'package:transfer_kit/src/core/driver/transfer_driver.dart';

import '../fake/fake_transfer_driver.dart';

void main() {
  group('UnsupportedCapabilityException', () {
    test('toString includes capability name when set', () {
      const ex = UnsupportedCapabilityException(
        'pause not supported',
        capability: 'supportsPause',
      );
      expect(ex.toString(), contains('supportsPause'));
      expect(ex.toString(), contains('pause not supported'));
    });

    test('toString works without capability name', () {
      const ex = UnsupportedCapabilityException('not supported');
      expect(ex.toString(), contains('not supported'));
    });
  });

  group('TransferCapabilities invariant', () {
    test(
      'assert fires when supportsResume is true but supportsPause is false',
      () {
        expect(
          () =>
              TransferCapabilities(supportsResume: true, supportsPause: false),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test('no assert when both supportsResume and supportsPause are true', () {
      expect(
        () => const TransferCapabilities(
          supportsResume: true,
          supportsPause: true,
        ),
        returnsNormally,
      );
    });
  });

  group('FakeTransferDriver capabilities', () {
    test(
      'pause throws UnsupportedCapabilityException when supportsPause=false',
      () async {
        final driver = FakeTransferDriver(supportsPause: false);
        expect(
          () => driver.pause('t1'),
          throwsA(isA<UnsupportedCapabilityException>()),
        );
      },
    );

    test(
      'resume throws UnsupportedCapabilityException when supportsPause=false',
      () async {
        final driver = FakeTransferDriver(supportsPause: false);
        expect(
          () => driver.resume('t1'),
          throwsA(isA<UnsupportedCapabilityException>()),
        );
      },
    );

    test('capabilities flag reflects supportsPause constructor param', () {
      final pausable = FakeTransferDriver(supportsPause: true);
      expect(pausable.capabilities.supportsPause, isTrue);
      expect(pausable.capabilities.supportsResume, isTrue);

      final nonPausable = FakeTransferDriver(supportsPause: false);
      expect(nonPausable.capabilities.supportsPause, isFalse);
      expect(nonPausable.capabilities.supportsResume, isFalse);
    });
  });
}
