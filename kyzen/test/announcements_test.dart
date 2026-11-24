import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyzen/models/announcement.dart';
import 'package:kyzen/services/announcements_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return '.';
          },
        );
  });

  group('Announcement and AnnouncementLink model tests', () {
    test('parses full Announcement JSON', () {
      final jsonMap = {
        'id': 'ann-101',
        'title': 'Welcome to Kyzen v1.5!',
        'body': 'Major performance updates and new features.',
        'date': '2026-07-26T14:00:00Z',
        'image_url': 'https://example.com/banner.png',
        'links': [
          {'label': 'Changelog', 'url': 'https://example.com/changelog'},
          {'label': 'Discord', 'url': 'https://discord.gg/XHgyapNEx8'},
        ],
      };

      final announcement = Announcement.fromJson(jsonMap);

      expect(announcement.id, 'ann-101');
      expect(announcement.title, 'Welcome to Kyzen v1.5!');
      expect(announcement.body, 'Major performance updates and new features.');
      expect(announcement.date, DateTime.parse('2026-07-26T14:00:00Z'));
      expect(announcement.imageUrl, 'https://example.com/banner.png');
      expect(announcement.links.length, 2);
      expect(announcement.links[0].label, 'Changelog');
      expect(announcement.links[0].url, 'https://example.com/changelog');
      expect(announcement.links[1].label, 'Discord');
      expect(announcement.links[1].url, 'https://discord.gg/XHgyapNEx8');
    });

    test('handles fallback and alternative field', () {
      final jsonMap = {
        '_id': 42,
        'heading': 'Alternative Heading',
        'content': 'Alternative content body',
        'banner': 'https://example.com/alt_banner.png',
        'action_links': ['https://example.com/raw_link'],
      };

      final announcement = Announcement.fromJson(jsonMap);

      expect(announcement.id, '42');
      expect(announcement.title, 'Alternative Heading');
      expect(announcement.body, 'Alternative content body');
      expect(announcement.imageUrl, 'https://example.com/alt_banner.png');
      expect(announcement.links.length, 1);
      expect(announcement.links[0].label, 'Link');
      expect(announcement.links[0].url, 'https://example.com/raw_link');
    });

    test(
      'parses unix timestamp dates correctly (seconds and milliseconds)',
      () {
        final jsonSeconds = {
          'id': 'sec-1',
          'title': 'Test',
          'body': 'Test',
          'date': 1700000000, // In seconds
        };
        final annSeconds = Announcement.fromJson(jsonSeconds);
        expect(
          annSeconds.date,
          DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        );

        final jsonMs = {
          'id': 'ms-1',
          'title': 'Test',
          'body': 'Test',
          'date': 1700000000000, // In milliseconds
        };
        final annMs = Announcement.fromJson(jsonMs);
        expect(annMs.date, DateTime.fromMillisecondsSinceEpoch(1700000000000));
      },
    );

    test('Announcement.toJson produces valid JSON map', () {
      final date = DateTime.parse('2026-07-26T12:00:00Z');
      final announcement = Announcement(
        id: 'json-1',
        title: 'Title',
        body: 'Body',
        date: date,
        imageUrl: 'https://example.com/img.png',
        links: const [
          AnnouncementLink(label: 'Label', url: 'https://example.com'),
        ],
      );

      final jsonMap = announcement.toJson();

      expect(jsonMap['id'], 'json-1');
      expect(jsonMap['title'], 'Title');
      expect(jsonMap['body'], 'Body');
      expect(jsonMap['date'], '2026-07-26T12:00:00.000Z');
      expect(jsonMap['image_url'], 'https://example.com/img.png');
      expect(jsonMap['links'], isA<List>());
      expect((jsonMap['links'] as List).length, 1);
    });

    test('parses root array or root map containing announcements key', () {
      const rawJsonArray = '''
      [
        {"id": "1", "title": "Ann 1", "body": "Body 1"},
        {"id": "2", "title": "Ann 2", "body": "Body 2"}
      ]
      ''';
      final decodedArray = jsonDecode(rawJsonArray) as List;
      final listFromArray = decodedArray
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(listFromArray.length, 2);
      expect(listFromArray[0].title, 'Ann 1');

      const rawJsonMap = '''
      {
        "announcements": [
          {"id": "10", "title": "Map Ann 1", "body": "Map Body 1"}
        ]
      }
      ''';
      final decodedMap = jsonDecode(rawJsonMap) as Map<String, dynamic>;
      final listFromMap = (decodedMap['announcements'] as List)
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(listFromMap.length, 1);
      expect(listFromMap[0].title, 'Map Ann 1');
    });
  });

  group('AnnouncementsService tests', () {
    test('parses announcements JSON', () {
      const rawJson = '''
{
  "announcements": [
    {
      "id": "4",
      "title": "Kyzen iOS support",
      "body": "We are looking forward to porting Kyzen to iOS\\n\\nTo make this happen, we need access to a macOS development environment (required for building and testing iOS apps). \\n\\nWe are gonna use MacInCloud's cloud plan , roughly €26/month after fees. (Goal €30)\\n\\nOnce the reached goal, the donations are going to be disabled.",
      "date": "2026-08-20T18:37:23.490Z",
      "image_url": "https://i.ibb.co/xtfZN0py/ios-kyzen.jpg",
      "links": [
        {
          "label": "Contribution link",
          "url": "https://ko-fi.com/notkyzen"
        }
      ]
    },
    {
      "id": "3",
      "title": "Kyzen official website",
      "body": "Here u can explore the official website",
      "date": "2026-08-17T12:00:00.000Z",
      "image_url": "https://i.ibb.co/KcFjPG6P/test2-1080p.jpg",
      "links": [
        {
          "label": "Website",
          "url": "https://kyzen.site/"
        }
      ]
    },
    {
      "id": "2",
      "title": "Kyzen 1.5.1 update",
      "body": "Recently Mojang added new dlc versions specifically optimized for mc 1.26.40+, we added a version picker.\\nIf u haven't updated kyzen go to settings -> scroll to bottom -> click \\"Check for updates\\" and update.",
      "date": "2026-08-13T19:59:49.333Z",
      "image_url": "https://i.ibb.co/TGZBC22/vrss.jpg"
    },
    {
      "id": "1",
      "title": "Welcome to Kyzen v1.5!",
      "body": "With more features, added New Announcements tab and auto updater.",
      "date": "2026-07-28T14:00:00Z",
      "image_url": "https://i.ibb.co/ZpF4MpV6/news-for-display.jpg",
      "links": [
        {
          "label": "Join Discord",
          "url": "https://discord.gg/XHgyapNEx8"
        },
        {
          "label": "Join Telegram",
          "url": "https://t.me/+gmyoKQUeX30wNTU0"
        }
      ]
    }
  ]
}
''';

      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final rawList = decoded['announcements'] as List<dynamic>;
      final announcements = rawList
          .whereType<Map<String, dynamic>>()
          .map(Announcement.fromJson)
          .toList();

      expect(announcements.length, 4);

      expect(announcements[0].id, '4');
      expect(announcements[0].title, 'Kyzen iOS support');
      expect(announcements[0].links.first.label, 'Contribution link');
      expect(announcements[0].links.first.url, 'https://ko-fi.com/notkyzen');

      expect(announcements[1].id, '3');
      expect(announcements[1].title, 'Kyzen official website');

      expect(announcements[2].id, '2');
      expect(announcements[2].title, 'Kyzen 1.5.1 update');
      expect(announcements[2].links, isEmpty);

      expect(announcements[3].id, '1');
      expect(announcements[3].title, 'Welcome to Kyzen v1.5!');
      expect(announcements[3].links.length, 2);
    });

    test('computeHash returns consistent 32-character MD5 hash', () {
      const jsonContent = '{"announcements":[{"id":"1","title":"Test 1"}]}';
      final hash1 = AnnouncementsService.computeHash(jsonContent);
      final hash2 = AnnouncementsService.computeHash(jsonContent);
      expect(hash1, equals(hash2));
      expect(hash1.length, 32);
    });

    test('markAsRead clears hasUnreadNotifier', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      AnnouncementsService.hasUnreadNotifier.value = true;
      await AnnouncementsService.markAsRead('{"id": "1", "title": "Test"}');
      expect(AnnouncementsService.hasUnreadNotifier.value, isFalse);
    });
  });
}
