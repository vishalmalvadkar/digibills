import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digi_bills/core/responsive/breakpoints.dart';
import 'package:digi_bills/core/responsive/max_width_container.dart';
import 'package:digi_bills/core/responsive/responsive_builder.dart';

void main() {
  group('Multi-Device Responsive Breakpoints Tests', () {
    testWidgets('Detects Compact Phone screen correctly (< 600dp)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? isCompactResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isCompactResult = context.isCompact;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isCompactResult, isTrue);
    });

    testWidgets('Detects Tablet screen correctly (600 - 1024dp)', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? isMediumResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMediumResult = context.isMedium;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isMediumResult, isTrue);
    });

    testWidgets('Detects Laptop/Desktop screen correctly (1024 - 1440dp)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? isExpandedResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isExpandedResult = context.isExpanded;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isExpandedResult, isTrue);
    });

    testWidgets('Detects 4K / Touchscreen Smartboard screen correctly (>= 1440dp)', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? isLargeResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isLargeResult = context.isLarge;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isLargeResult, isTrue);
    });

    testWidgets('MaxWidthContainer correctly clamps content on wide screens', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaxWidthContainer(
              maxWidth: 1200,
              child: Text('Clamped Content'),
            ),
          ),
        ),
      );

      final constrainedBoxFinder = find.descendant(
        of: find.byType(MaxWidthContainer),
        matching: find.byType(ConstrainedBox),
      );
      expect(constrainedBoxFinder, findsOneWidget);

      final ConstrainedBox box = tester.widget(constrainedBoxFinder);
      expect(box.constraints.maxWidth, equals(1200.0));
      expect(find.text('Clamped Content'), findsOneWidget);
    });
  });
}
