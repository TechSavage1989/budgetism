import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/date_controls.dart';

Future<void> tapDateDay(WidgetTester tester, String day) async {
  final calendar = find.byType(CalendarDatePicker);
  expect(calendar, findsOneWidget);
  await tester.tap(find.descendant(of: calendar, matching: find.text(day)).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Use date'));
  await tester.pumpAndSettle();
}

void main() {
  test('strict calendar values reject rollover and timezone text without changing dates', () {
    for (final invalid in ['2026-02-30', '2025-02-29', '2026-13-01', '2026-00-10', '1899-12-31',
      '10000-01-01', '2026-1-01', '10/28/2026', '2026-10-28T00:00:00Z', '']) {
      expect(FinanceDates.parse(invalid), isNull, reason: invalid);
    }
    expect(FinanceDates.format(FinanceDates.parse('2024-02-29')!), '2024-02-29');
    expect(FinanceDates.format(DateTime.utc(2026, 3, 8, 23)), '2026-03-08');
    expect(FinanceDates.format(FinanceDates.shift(DateTime(2026, 3, 8), 1)), '2026-03-09');
    expect(FinanceDates.format(FinanceDates.shift(DateTime(2026, 11, 1), -1)), '2026-10-31');
    expect(FinanceDates.parse('9999-12-31'), FinanceDates.last);
  });
  test('inclusive presets handle month/year boundaries, leap days and lower limit', () {
    final today = DateTime(2024, 3, 1);
    expect(FinanceDates.preset('Today', today), ('2024-03-01', '2024-03-01'));
    expect(FinanceDates.preset('Last 7 days', today), ('2024-02-24', '2024-03-01'));
    expect(FinanceDates.preset('Last 30 days', today), ('2024-02-01', '2024-03-01'));
    expect(FinanceDates.preset('Month to date', today), ('2024-03-01', '2024-03-01'));
    expect(FinanceDates.preset('Last month', today), ('2024-02-01', '2024-02-29'));
    expect(FinanceDates.preset('Last month', DateTime(2026, 1, 1)), ('2025-12-01', '2025-12-31'));
    expect(FinanceDates.preset('Year to date', today), ('2024-01-01', '2024-03-01'));
    expect(FinanceDates.preset('Last 30 days', FinanceDates.first), ('1900-01-01', '1900-01-01'));
  });

  for (final width in [430.0, 1100.0]) {
    testWidgets('calendar selection and manual entry coexist at $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 850); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: '2026-10-10'); addTearDown(controller.dispose);
      final changes = <String>[];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(20),
        child: FinanceDateField(controller: controller, label: 'Date', fieldKey: const Key('date'),
          today: DateTime(2026, 10, 28), allowEmpty: true, onChanged: changes.add)))));
      await tester.tap(find.byTooltip('Choose date: Date')); await tester.pumpAndSettle();
      expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).initialEntryMode, DatePickerEntryMode.calendar);
      expect(controller.text, '2026-10-10'); expect(changes, isEmpty);
      await tapDateDay(tester, '15');
      expect(controller.text, '2026-10-15'); expect(changes, ['2026-10-15']);
      await tester.enterText(find.byKey(const Key('date')), '2026-10-16');
      expect(controller.text, '2026-10-16'); expect(changes.last, '2026-10-16');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('invalid text opens a usable calendar; cancelling never fixes or clears the field', (tester) async {
    final controller = TextEditingController(text: '2026-02-30'); addTearDown(controller.dispose);
    var changes = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceDateField(controller: controller,
      label: 'Date', today: DateTime(2026, 10, 28), onChanged: (_) => changes++))));
    await tester.tap(find.byTooltip('Choose date: Date')); await tester.pumpAndSettle();
    expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).initialDate, DateTime(2026, 10, 28));
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
    expect(controller.text, '2026-02-30'); expect(changes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('today and optional clear notify once and unchanged dates do not invalidate review', (tester) async {
    final controller = TextEditingController(text: '2026-10-10'); addTearDown(controller.dispose);
    final changes = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceDateField(controller: controller,
      label: 'Date', today: DateTime(2026, 10, 28), allowEmpty: true, onChanged: changes.add))));
    await tester.tap(find.byTooltip('Today: Date')); await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Today: Date')); await tester.pumpAndSettle();
    expect(changes, ['2026-10-28']);
    await tester.tap(find.byTooltip('Choose date: Date')); await tester.pumpAndSettle();
    await tester.tap(find.text('Use date')); await tester.pumpAndSettle();
    expect(changes, ['2026-10-28']);
    await tester.tap(find.byTooltip('Clear: Date')); await tester.pumpAndSettle();
    expect(controller.text, ''); expect(changes, ['2026-10-28', '']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('locked or disabled fields cannot open a calendar or alter date', (tester) async {
    final controller = TextEditingController(text: '2026-10-10'); addTearDown(controller.dispose);
    for (final readOnly in [true, false]) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceDateField(controller: controller,
        label: 'Locked date', enabled: readOnly, readOnly: readOnly, allowEmpty: true))));
      final calendar = find.widgetWithIcon(IconButton, Icons.calendar_month_outlined);
      expect(tester.widget<IconButton>(calendar).onPressed, isNull);
      await tester.tap(calendar); await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing); expect(controller.text, '2026-10-10');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('bounds clamp only the picker seed, prevent invalid shortcuts and handle terminal dates', (tester) async {
    final controller = TextEditingController(text: '2026-10-01'); addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceDateField(controller: controller,
      label: 'Date', firstDate: DateTime(2026, 11, 1), lastDate: DateTime(2026, 11, 30), today: DateTime(2026, 10, 28)))));
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.today_outlined)).onPressed, isNull);
    await tester.tap(find.byTooltip('Choose date: Date')); await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.initialDate, DateTime(2026, 11, 1)); expect(picker.firstDate, DateTime(2026, 11, 1));
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); expect(controller.text, '2026-10-01');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceDateField(controller: controller,
      label: 'Date', firstDate: DateTime(10000)))));
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.calendar_month_outlined)).onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a changed controller while calendar is open is not overwritten on return', (tester) async {
    final controller = TextEditingController(text: '2026-10-10'); addTearDown(controller.dispose);
    var changes = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceDateField(controller: controller,
      label: 'Date', onChanged: (_) => changes++))));
    await tester.tap(find.byTooltip('Choose date: Date')); await tester.pumpAndSettle();
    controller.text = '2026-12-01'; await tapDateDay(tester, '15');
    expect(controller.text, '2026-12-01'); expect(changes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [430.0, 1100.0]) {
    testWidgets('range calendar and presets fit $width pixels and cancel is read-only', (tester) async {
      tester.view.physicalSize = Size(width, 850); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final changes = <(String, String)>[];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceDateRangeBar(
        from: '2026-10-01', through: '2026-10-28', today: DateTime(2026, 10, 28), allowAll: true,
        onChanged: (from, through) => changes.add((from, through))))));
      await tester.tap(find.text('Choose date range')); await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Closing the route is also how Escape/back dismisses the range picker.
      Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(); await tester.pumpAndSettle();
      expect(changes, isEmpty);
      await tester.tap(find.text('Last 7 days')); await tester.pumpAndSettle();
      expect(changes.single, ('2026-10-22', '2026-10-28'));
      await tester.tap(find.text('All dates')); await tester.pumpAndSettle(); expect(changes.last, ('', ''));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('range acceptance returns inclusive endpoints and existing future limit is retained', (tester) async {
    DateTimeRange? chosen;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () async { chosen = await chooseFinanceRange(context, from: '2026-10-01', through: '2026-10-28',
        lastDate: DateTime(2026, 10, 28), today: DateTime(2026, 10, 28)); }, child: const Text('Range'))))));
    await tester.tap(find.text('Range')); await tester.pumpAndSettle();
    expect(tester.widget<DateRangePickerDialog>(find.byType(DateRangePickerDialog)).lastDate, DateTime(2026, 10, 28));
    await tester.tap(find.text('Use dates')); await tester.pumpAndSettle();
    expect(FinanceDates.format(chosen!.start), '2026-10-01'); expect(FinanceDates.format(chosen!.end), '2026-10-28');
  });

  testWidgets('invalid custom range starts empty and cancelling does not emit a replacement', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceDateRangeBar(
      from: '2026-11-01', through: '2026-10-01', onChanged: (_, _) => calls++))));
    await tester.tap(find.text('Choose date range')); await tester.pumpAndSettle();
    expect(tester.widget<DateRangePickerDialog>(find.byType(DateRangePickerDialog)).initialDateRange, isNull);
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(); await tester.pumpAndSettle();
    expect(calls, 0); expect(tester.takeException(), isNull);
  });

  testWidgets('month grid and year calendar choose a month without typing or submitting early', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () async { selected = await showDialog<String>(context: context,
        builder: (_) => FinanceMonthDialog(month: '2026-10', today: DateTime(2026, 10, 28))); },
      child: const Text('Month'))))));
    await tester.tap(find.text('Month')); await tester.pumpAndSettle(); expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('budget-year'))); await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(YearPicker), matching: find.text('2025'))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget-month-2'))); await tester.pumpAndSettle(); expect(selected, isNull);
    await tester.tap(find.text('Go to month')); await tester.pumpAndSettle(); expect(selected, '2025-02');
  });
}
