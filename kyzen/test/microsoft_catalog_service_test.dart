import 'package:flutter_test/flutter_test.dart';
import 'package:kyzen/dev_menu/models/microsoft_catalog_models.dart';
import 'package:kyzen/dev_menu/services/microsoft_catalog_service.dart';

void main() {
  group('MicrosoftCatalogProduct Parsing Tests', () {
    test('parses single product JSON format (Product wrapper)', () {
      const raw = '''
      {
        "Product": {
          "ProductId": "9NBLGGH2JHXJ",
          "LocalizedProperties": [
            {
              "ProductTitle": "Minecraft for Windows",
              "PublisherName": "Mojang",
              "Images": [
                {
                  "ImagePurpose": "BoxArt",
                  "Uri": "//store-images.s-microsoft.com/image/apps.1234.png"
                }
              ]
            }
          ],
          "MarketProperties": [
            {
              "OriginalReleaseDate": "2015-07-29T00:00:00Z"
            }
          ],
          "Properties": {
            "PackageFamilyName": "Microsoft.MinecraftUWP_8wekyb3d8bbwe",
            "Category": "Action & adventure"
          },
          "ProductKind": "Game",
          "DisplaySkuAvailabilities": [
            {
              "Availabilities": [
                {
                  "OrderManagementData": {
                    "Price": {
                      "CurrencyCode": "USD",
                      "ListPrice": 19.99
                    }
                  }
                }
              ]
            }
          ]
        }
      }
      ''';

      final response = MicrosoftCatalogResponse.fromHttp(
        statusCode: 200,
        durationMs: 120,
        url: 'https://displaycatalog.mp.microsoft.com/v7/products/9NBLGGH2JHXJ',
        rawString: raw,
      );

      expect(response.isSuccess, isTrue);
      expect(response.products.length, 1);

      final p = response.products.first;
      expect(p.productId, '9NBLGGH2JHXJ');
      expect(p.title, 'Minecraft for Windows');
      expect(p.publisherName, 'Mojang');
      expect(p.packageFamilyName, 'Microsoft.MinecraftUWP_8wekyb3d8bbwe');
      expect(
        p.imageUrl,
        'https://store-images.s-microsoft.com/image/apps.1234.png',
      );
      expect(p.priceFormatted, 'USD 19.99');
      expect(p.productKind, 'Game');
    });

    test('parses lookup response format (Products array)', () {
      const raw = '''
      {
        "TotalResultCount": 908,
        "HasMorePages": true,
        "BigIds": ["9MSZP0B4RHTM"],
        "Products": [
          {
            "ProductId": "9MSZP0B4RHTM",
            "LocalizedProperties": [
              {
                "ProductTitle": "Add-on Pack 1"
              }
            ],
            "ProductKind": "UnmanagedConsumable"
          }
        ]
      }
      ''';

      final response = MicrosoftCatalogResponse.fromHttp(
        statusCode: 200,
        durationMs: 85,
        url:
            'https://displaycatalog.mp.microsoft.com/v7/products/lookup?value=9NBLGGH2JHXJ',
        rawString: raw,
      );

      expect(response.isSuccess, isTrue);
      expect(response.totalResultCount, 908);
      expect(response.hasMorePages, isTrue);
      expect(response.bigIds, ['9MSZP0B4RHTM']);
      expect(response.products.length, 1);
      expect(response.products.first.title, 'Add-on Pack 1');
      expect(response.products.first.productId, '9MSZP0B4RHTM');
    });
  });

  group('MicrosoftCatalogService Live Request Tests', () {
    test(
      'fetch real product details for Minecraft Windows (9NBLGGH2JHXJ)',
      () async {
        final response = await MicrosoftCatalogService.instance
            .getProductDetails(productId: '9NBLGGH2JHXJ');

        expect(response.statusCode, 200);
        expect(response.isSuccess, isTrue);
        expect(response.products.isNotEmpty, isTrue);
        expect(
          response.products.first.title.toLowerCase(),
          contains('minecraft'),
        );
      },
    );

    test('lookup real related products for 9NBLGGH2JHXJ with top=2', () async {
      final response = await MicrosoftCatalogService.instance.lookupProducts(
        productId: '9NBLGGH2JHXJ',
        top: 2,
        skip: 0,
      );

      expect(response.statusCode, 200);
      expect(response.isSuccess, isTrue);
      expect(response.totalResultCount, isNotNull);
      expect(response.totalResultCount! > 0, isTrue);
    });

    test(
      'scrapeAllProducts collects products with progress callback',
      () async {
        int lastReportedCurrent = 0;
        int lastReportedTotal = 0;
        int lastReportedFound = 0;

        final response = await MicrosoftCatalogService.instance
            .scrapeAllProducts(
              productId: '9P5786PJB9RP',
              pageSize: 25,
              onProgress: (current, total, found) {
                lastReportedCurrent = current;
                lastReportedTotal = total;
                lastReportedFound = found;
              },
            );

        expect(response.statusCode, 200);
        expect(response.isSuccess, isTrue);
        expect(response.products.isNotEmpty, isTrue);
        expect(lastReportedTotal, greaterThan(0));
        expect(lastReportedCurrent, greaterThan(0));
        expect(lastReportedFound, greaterThan(0));
        expect(response.json, isA<Map<String, dynamic>>());
        final map = response.json as Map<String, dynamic>;
        expect(map.containsKey('Products'), isTrue);
        expect(map.containsKey('TotalResultCount'), isTrue);
      },
    );
  });
}
