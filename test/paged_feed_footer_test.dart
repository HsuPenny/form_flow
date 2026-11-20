import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_flow/data/paged_feed.dart';
import 'package:flutter_form_flow/theme/app_theme.dart';
import 'package:flutter_form_flow/widgets/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a loading batch covers the app until it lands', (tester) async {
    final batch = Completer<PageResult<int>>();
    final feed = PagedFeed<int>((_) => batch.future);
    addTearDown(feed.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: feed,
            builder: (context, _) => PagedFeedFooter(feed),
          ),
        ),
      ),
    );

    feed.loadMore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LoadingOverlay), findsOneWidget);

    batch.complete(const PageResult([1, 2], 2));
    await tester.pump();
    await tester.pump();
    expect(find.byType(LoadingOverlay), findsNothing);
    expect(find.text('已經沒有更多了'), findsOneWidget);
  });
}
