import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_form_flow/data/models.dart';

void main() {
  group('FormItem.statusFor', () {
    const me = Member('me', '我', '工程部');
    const other = Member('other', '同事', '工程部');

    FormItem form(FormStatus status, {List<Member> responded = const []}) =>
        FormItem(
          id: 'f1',
          title: '表單',
          description: '',
          deadline: DateTime(2026, 10, 20),
          status: status,
          questions: [],
          recipients: [me, other],
          responses: [
            for (final m in responded)
              FormResponse(
                member: m,
                submittedAt: DateTime(2026, 10, 13),
                answers: {},
              ),
          ],
        );

    test('pending until I respond, even if others have', () {
      expect(form(FormStatus.pending).statusFor(me), FormStatus.pending);
      expect(
        form(FormStatus.pending, responded: [other]).statusFor(me),
        FormStatus.pending,
      );
    });

    test('completed once I respond, even if others have not', () {
      expect(
        form(FormStatus.pending, responded: [me]).statusFor(me),
        FormStatus.completed,
      );
    });

    test('a completed form I have not answered is still pending for me', () {
      // e.g. I was added as a recipient after everyone else had replied.
      expect(form(FormStatus.completed).statusFor(me), FormStatus.pending);
    });

    test('a closed form is completed if I answered, else closed', () {
      expect(
        form(FormStatus.closed, responded: [me]).statusFor(me),
        FormStatus.completed,
      );
      expect(form(FormStatus.closed).statusFor(me), FormStatus.closed);
    });

    test('drafts stay drafts', () {
      expect(
        form(FormStatus.draft, responded: [me]).statusFor(me),
        FormStatus.draft,
      );
    });
  });

  group('FormItem.isOpen', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    FormItem dueOn(
      DateTime deadline, {
      FormStatus status = FormStatus.pending,
    }) => FormItem(
      id: 'f1',
      title: '表單',
      description: '',
      deadline: deadline,
      status: status,
      questions: [],
      recipients: [],
    );
    final yesterday = today.subtract(const Duration(days: 1));

    test('open through the end of the deadline day', () {
      expect(dueOn(today).isOpen, isTrue);
      expect(dueOn(today.add(const Duration(days: 1))).isOpen, isTrue);
    });

    test('closed from the day after the deadline', () {
      expect(dueOn(yesterday).isOpen, isFalse);
    });

    test('drafts and closed forms are never open', () {
      expect(dueOn(today, status: FormStatus.draft).isOpen, isFalse);
      expect(dueOn(today, status: FormStatus.closed).isOpen, isFalse);
    });

    test('only pending forms can get a later deadline, even past it', () {
      expect(dueOn(yesterday).canExtendDeadline, isTrue);
      expect(
        dueOn(today, status: FormStatus.completed).canExtendDeadline,
        isFalse,
      );
      expect(
        dueOn(today, status: FormStatus.closed).canExtendDeadline,
        isFalse,
      );
    });
  });
}
