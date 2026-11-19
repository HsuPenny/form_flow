import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_form_flow/data/paged_feed.dart';
import 'package:flutter_form_flow/data/models.dart';
import 'package:flutter_form_flow/data/repositories/form_repository.dart';
import 'package:flutter_form_flow/data/repositories/mock_form_repository.dart';

FormItem _form(String id, {DateTime? deadline}) => FormItem(
  id: id,
  title: '表單 $id',
  description: '',
  deadline: deadline ?? DateTime(2026, 1, 1),
  status: FormStatus.pending,
  questions: [],
  recipients: [],
);

void main() {
  group('FormItem.isExpiredFor', () {
    const me = Member('me', '我', '工程部');
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final today = DateTime.now();

    FormItem form(
      FormStatus status,
      DateTime deadline, {
      bool responded = false,
    }) => FormItem(
      id: 'f',
      title: '表單',
      description: '',
      deadline: DateTime(deadline.year, deadline.month, deadline.day),
      status: status,
      questions: [],
      recipients: [me],
      responses: [
        if (responded)
          FormResponse(member: me, submittedAt: DateTime.now(), answers: {}),
      ],
    );

    test('past the deadline without my reply', () {
      expect(form(FormStatus.pending, yesterday).isExpiredFor(me), isTrue);
    });

    test('still open through the deadline day', () {
      expect(form(FormStatus.pending, today).isExpiredFor(me), isFalse);
    });

    test('closed by an admin before the deadline', () {
      expect(form(FormStatus.closed, today).isExpiredFor(me), isTrue);
    });

    test('not once I have replied, nor for drafts', () {
      expect(
        form(FormStatus.pending, yesterday, responded: true).isExpiredFor(me),
        isFalse,
      );
      expect(form(FormStatus.draft, yesterday).isExpiredFor(me), isFalse);
    });
  });

  group('MockFormRepository.fetchMyForms', () {
    test('pages through matches, latest deadline first', () async {
      final repo = MockFormRepository();
      final me = (await repo.fetchMembers()).first;
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      for (var i = 0; i < 5; i++) {
        await repo.saveForm(
          _form('x$i', deadline: yesterday.subtract(Duration(days: i)))
            ..recipients.add(me),
        );
      }

      final first = await repo.fetchMyForms(
        memberId: me.id,
        kind: FormCategory.expired,
        limit: 3,
      );
      expect(first.items.map((f) => f.id), ['x0', 'x1', 'x2']);
      final rest = await repo.fetchMyForms(
        memberId: me.id,
        kind: FormCategory.expired,
        offset: 3,
        limit: 3,
      );
      expect(rest.items.map((f) => f.id), containsAllInOrder(['x3', 'x4']));
      expect(rest.total, first.total);
      expect(
        [...first.items, ...rest.items].every((f) => f.isExpiredFor(me)),
        isTrue,
      );
    });
  });

  group('PagedFeed', () {
    test('loads batch after batch until the total is reached', () async {
      final all = [for (var i = 0; i < 5; i++) _form('f$i')];
      final offsets = <int>[];
      final feed = PagedFeed<FormItem>((offset) async {
        offsets.add(offset);
        return PageResult(all.skip(offset).take(2).toList(), all.length);
      });

      await feed.reload();
      expect(feed.items, hasLength(2));
      expect(feed.hasMore, isTrue);
      await feed.loadMore();
      await feed.loadMore();
      expect(feed.items.map((f) => f.id), ['f0', 'f1', 'f2', 'f3', 'f4']);
      expect(feed.hasMore, isFalse);
      await feed.loadMore();
      expect(offsets, [0, 2, 4]);
    });

    test('keeps a failure for retrying instead of throwing', () async {
      var fail = true;
      final feed = PagedFeed<FormItem>((offset) async {
        if (fail) throw StateError('offline');
        return PageResult([_form('f0')], 1);
      });

      await feed.reload();
      expect(feed.error, isA<StateError>());
      expect(feed.isLoading, isFalse);
      fail = false;
      // Scrolling alone doesn't hammer a failing server; the retry button does.
      await feed.loadMore();
      expect(feed.error, isA<StateError>());
      await feed.loadMore(retry: true);
      expect(feed.error, isNull);
      expect(feed.items, hasLength(1));
    });

    test('a reload drops the batch it replaced', () async {
      final slow = Completer<PageResult<FormItem>>();
      var calls = 0;
      final feed = PagedFeed<FormItem>((offset) {
        calls++;
        return calls == 1
            ? slow.future
            : Future.value(PageResult([_form('new')], 1));
      });

      final stale = feed.reload();
      await feed.reload();
      slow.complete(PageResult([_form('old')], 1));
      await stale;
      expect(feed.items.map((f) => f.id), ['new']);
    });
  });
}
