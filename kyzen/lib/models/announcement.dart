class AnnouncementLink {
  final String label;
  final String url;

  const AnnouncementLink({required this.label, required this.url});

  factory AnnouncementLink.fromJson(Map<String, dynamic> json) {
    return AnnouncementLink(
      label: (json['label'] ?? json['title'] ?? 'Link').toString(),
      url: (json['url'] ?? json['link'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'url': url};
}

class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime? date;
  final String? imageUrl;
  final List<AnnouncementLink> links;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.date,
    this.imageUrl,
    this.links = const [],
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    // ID
    final rawId = json['id'] ?? json['_id'] ?? json['uuid'];
    final idStr = rawId != null
        ? rawId.toString()
        : DateTime.now().microsecondsSinceEpoch.toString();

    // title and body
    final title = (json['title'] ?? json['heading'] ?? '').toString();
    final body = (json['body'] ?? json['content'] ?? json['description'] ?? '')
        .toString();

    // date
    DateTime? parsedDate;
    final rawDate = json['date'] ?? json['created_at'] ?? json['timestamp'];
    if (rawDate != null) {
      if (rawDate is String) {
        parsedDate = DateTime.tryParse(rawDate);
      } else if (rawDate is int) {
        if (rawDate > 10000000000) {
          parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
        } else {
          parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate * 1000);
        }
      }
    }

    // image URL
    final rawImage =
        json['image_url'] ??
        json['image'] ??
        json['imageUrl'] ??
        json['banner'];
    final imageUrl = (rawImage != null && rawImage.toString().trim().isNotEmpty)
        ? rawImage.toString().trim()
        : null;

    // links
    final List<AnnouncementLink> linkList = [];
    final rawLinks = json['links'] ?? json['urls'] ?? json['action_links'];
    if (rawLinks is List) {
      for (final item in rawLinks) {
        if (item is Map<String, dynamic>) {
          final link = AnnouncementLink.fromJson(item);
          if (link.url.isNotEmpty) {
            linkList.add(link);
          }
        } else if (item is String && item.isNotEmpty) {
          linkList.add(AnnouncementLink(label: 'Link', url: item));
        }
      }
    }

    return Announcement(
      id: idStr,
      title: title,
      body: body,
      date: parsedDate,
      imageUrl: imageUrl,
      links: linkList,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    if (date != null) 'date': date!.toIso8601String(),
    if (imageUrl != null) 'image_url': imageUrl,
    'links': links.map((l) => l.toJson()).toList(),
  };
}
