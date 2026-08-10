import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recognition_camera/presentation/detection/widgets/scan_home_view.dart';

/// Counts what the host screen would have been asked to do.
class _Actions {
  int camera = 0;
  int gallery = 0;
  int barcode = 0;
}

/// Pumps the scan tab's idle state with the mode switch wired up the way the
/// detection screen wires it, so the test exercises the real state change
/// rather than two separately-constructed widgets.
Future<_Actions> _pumpHome(WidgetTester tester) async {
  final actions = _Actions();
  var mode = ScanMode.photo;

  await tester.pumpWidget(
    MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: ScanHomeView(
            mode: mode,
            onModeChanged: (next) => setState(() => mode = next),
            onOpenCamera: () => actions.camera++,
            onPickFromGallery: () => actions.gallery++,
            onScanBarcode: () => actions.barcode++,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return actions;
}

Future<void> _switchToBarcode(WidgetTester tester) async {
  await tester.tap(find.text('Barcode'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('photo mode offers the camera and the gallery', (tester) async {
    await _pumpHome(tester);

    expect(find.text('Open camera'), findsOneWidget);
    expect(find.text('Choose a photo'), findsOneWidget);
    expect(find.text('Scan barcode'), findsNothing);
  });

  testWidgets('switching to barcode swaps the action', (tester) async {
    await _pumpHome(tester);
    await _switchToBarcode(tester);

    expect(find.text('Scan barcode'), findsOneWidget);
    expect(find.text('Open camera'), findsNothing);
    // The gallery has no meaning here: a photo of a barcode is not a scan of
    // one, and offering it would produce a photo-path result under a barcode
    // heading.
    expect(find.text('Choose a photo'), findsNothing);
  });

  testWidgets('each mode states what its answer is worth', (tester) async {
    await _pumpHome(tester);

    // The expectation is set before the scan, not apologised for after it.
    expect(
      find.textContaining('Everything it returns is an estimate'),
      findsOneWidget,
    );

    await _switchToBarcode(tester);
    expect(
      find.textContaining('same barcode gives the same answer'),
      findsOneWidget,
    );
  });

  testWidgets('the visible action is the one that runs', (tester) async {
    final actions = await _pumpHome(tester);

    await tester.tap(find.text('Open camera'));
    await tester.pumpAndSettle();
    expect(actions.camera, 1);
    expect(actions.barcode, 0);

    await _switchToBarcode(tester);
    await tester.tap(find.text('Scan barcode'));
    await tester.pumpAndSettle();
    expect(actions.barcode, 1);
    expect(actions.camera, 1);
  });
}
