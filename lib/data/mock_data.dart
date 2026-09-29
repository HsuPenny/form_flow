import 'models.dart';

class MockData {
  static const members = [
    Member('林郁婷', '產品設計'),
    Member('陳柏安', '工程部'),
    Member('吳思妤', '客戶成功'),
    Member('黃子軒', '行銷企劃'),
    Member('張雅雯', '財務行政'),
    Member('蔡承翰', '工程部'),
    Member('李冠廷', '業務開發'),
    Member('周品妍', '人資'),
    Member('許家豪', '工程部'),
    Member('鄭宇翔', '工程部'),
    Member('高詩涵', '產品設計'),
    Member('楊凱文', '客戶成功'),
    Member('謝佳穎', '行銷企劃'),
    Member('林志明', '業務開發'),
    Member('張雅婷', '業務開發'),
    Member('周美玲', '財務行政'),
    Member('王思涵', '人資'),
  ];

  static List<FormItem> forms() {
    final workshopQuestions = [
      Question(
        title: '這次的會議節奏是否適合你的工作安排？',
        type: QuestionType.single,
        required: true,
        options: ['非常適合', '大致適合', '需要調整'],
      ),
      Question(
        title: '你希望下次工作坊增加哪些內容？',
        type: QuestionType.multiple,
        required: false,
        options: ['實作演練', '案例分享', '跨部門交流', '會後資料包'],
      ),
    ];

    final securityQuestions = [
      Question(
        title: '收到可疑的登入連結時，你會怎麼做？',
        type: QuestionType.single,
        options: ['直接點擊確認', '回報資安窗口', '轉寄給同事'],
      ),
      Question(
        title: '哪些資料不應該貼到公開頻道？',
        type: QuestionType.multiple,
        options: ['客戶個資', '內部密碼', '會議時間', '合約內容'],
      ),
      Question(
        title: '你覺得公司還可以加強哪方面的資安宣導？',
        type: QuestionType.paragraph,
        required: false,
        options: [],
      ),
    ];

    return [
      FormItem(
        id: 'f1',
        title: '2026 Q3 產品策略工作坊回饋',
        description: '收集本次工作坊的即時回饋，協助我們把下一次活動做得更精準。',
        deadline: DateTime(2026, 9, 30),
        status: FormStatus.pending,
        questions: workshopQuestions,
        recipients: members.sublist(0, 6),
        responses: [
          FormResponse(
            member: members[0],
            submittedAt: DateTime(2026, 9, 21, 14, 22),
            answers: {
              0: '非常適合',
              1: {'實作演練', '案例分享'},
            },
          ),
          FormResponse(
            member: members[1],
            submittedAt: DateTime(2026, 9, 21, 16, 8),
            answers: {
              0: '大致適合',
              1: {'實作演練'},
            },
          ),
          FormResponse(
            member: members[2],
            submittedAt: DateTime(2026, 9, 22, 9, 14),
            answers: {
              0: '非常適合',
              1: {'跨部門交流', '會後資料包'},
            },
          ),
          FormResponse(
            member: members[3],
            submittedAt: DateTime(2026, 9, 22, 11, 42),
            answers: {
              0: '需要調整',
              1: {'案例分享'},
            },
          ),
        ],
      ),
      FormItem(
        id: 'f2',
        title: '資訊安全意識年度檢核',
        description: '請完成年度安全意識小測驗，花費約 3 分鐘。',
        deadline: DateTime(2026, 10, 8),
        status: FormStatus.pending,
        questions: securityQuestions,
        recipients: members.sublist(0, 8),
        responses: [
          for (var i = 0; i < 7; i++)
            FormResponse(
              member: members[i],
              submittedAt: DateTime(2026, 9, 18 + i ~/ 2, 10 + i, 5 * i),
              answers: {
                0: '回報資安窗口',
                1: {'客戶個資', '內部密碼'},
                2: i.isEven ? '希望多一些實際案例' : '',
              },
            ),
        ],
      ),
      FormItem(
        id: 'f3',
        title: '專案結案回顧｜星港改版',
        description: '整理專案過程中的觀察，讓團隊把有效的方法留下來。',
        deadline: DateTime(2026, 10, 15),
        status: FormStatus.draft,
        questions: [
          Question(title: '你的聯絡信箱', type: QuestionType.shortText, options: []),
          Question(
            title: '你在專案中的角色',
            type: QuestionType.dropdown,
            options: ['專案經理', '設計', '前端工程', '後端工程', '測試'],
          ),
          Question(
            title: '你最後一次參與專案的日期',
            type: QuestionType.date,
            required: false,
            options: [],
          ),
          Question(
            title: '整體來說，這次合作的順暢程度？',
            type: QuestionType.single,
            options: ['非常順暢', '還算順暢', '不太順暢'],
            allowOther: true,
          ),
          Question(
            title: '哪些工具對你幫助最大？',
            type: QuestionType.multiple,
            required: false,
            options: ['Figma', 'Jira', 'Slack', 'Notion'],
          ),
          Question(
            title: '這個專案中最有效的做法是什麼？',
            type: QuestionType.paragraph,
            options: [],
          ),
        ],
        recipients: [],
      ),
    ];
  }
}
