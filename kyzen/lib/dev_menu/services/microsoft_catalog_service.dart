import 'dart:async';
import 'dart:convert';
import 'package:kyzen/services/http_client.dart';
import '../models/microsoft_catalog_models.dart';

class MicrosoftCatalogService {
  MicrosoftCatalogService._internal();
  static final MicrosoftCatalogService instance =
      MicrosoftCatalogService._internal();
  factory MicrosoftCatalogService() => instance;

  static const String host = 'displaycatalog.mp.microsoft.com';

  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  Future<MicrosoftCatalogResponse> lookupProducts({
    required String productId,
    String market = 'US',
    String languages = 'en-US',
    int top = 25,
    int skip = 0,
    String alternateId = 'SellableBy',
  }) async {
    final queryParams = <String, String>{
      'value': productId.trim(),
      'market': market.trim().isEmpty ? 'US' : market.trim(),
      'languages': languages.trim().isEmpty ? 'en-US' : languages.trim(),
      r'$top': top.toString(),
      r'$skip': skip.toString(),
      'alternateId': alternateId.trim().isEmpty
          ? 'SellableBy'
          : alternateId.trim(),
    };

    final uri = Uri.https(host, '/v7/products/lookup', queryParams);
    return _executeRequest(uri);
  }

  /// Scrape all products across all pages for a given product ID
  Future<MicrosoftCatalogResponse> scrapeAllProducts({
    required String productId,
    String market = 'US',
    String languages = 'en-US',
    String alternateId = 'SellableBy',
    int pageSize = 25,
    void Function(
      int currentCandidates,
      int totalCandidates,
      int productsFound,
    )?
    onProgress,
    bool Function()? isCancelled,
    Duration delayBetweenPages = const Duration(milliseconds: 150),
  }) async {
    final cleanId = productId.trim();
    final stopwatch = Stopwatch()..start();

    final firstResponse = await lookupProducts(
      productId: cleanId,
      market: market,
      languages: languages,
      top: pageSize,
      skip: 0,
      alternateId: alternateId,
    );

    if (!firstResponse.isSuccess ||
        firstResponse.json is! Map<String, dynamic>) {
      stopwatch.stop();
      return firstResponse;
    }

    final firstMap = firstResponse.json as Map<String, dynamic>;
    final totalCandidates =
        firstResponse.totalResultCount ?? firstResponse.products.length;

    final rawPages = <Map<String, dynamic>>[firstMap];
    final seenProductIds = <String>{};
    final mergedProducts = <Map<String, dynamic>>[];
    final mergedBigIds = <String>{};

    void extractFromPage(Map<String, dynamic> pageMap) {
      if (pageMap['BigIds'] is List) {
        for (final id in pageMap['BigIds']) {
          if (id != null) mergedBigIds.add(id.toString());
        }
      }
      if (pageMap['Products'] is List) {
        for (final p in pageMap['Products']) {
          if (p is Map<String, dynamic>) {
            final id = p['ProductId']?.toString();
            if (id != null && id.isNotEmpty) {
              if (seenProductIds.add(id)) {
                mergedProducts.add(p);
              }
            } else {
              mergedProducts.add(p);
            }
          }
        }
      }
    }

    extractFromPage(firstMap);

    onProgress?.call(
      totalCandidates > 0
          ? (totalCandidates > pageSize ? pageSize : totalCandidates)
          : mergedProducts.length,
      totalCandidates,
      mergedProducts.length,
    );

    // Paginate remaining pages if totalCandidates > pageSize
    if (totalCandidates > pageSize) {
      for (int skip = pageSize; skip < totalCandidates; skip += pageSize) {
        if (isCancelled?.call() == true) {
          break;
        }

        if (delayBetweenPages > Duration.zero) {
          await Future.delayed(delayBetweenPages);
        }

        if (isCancelled?.call() == true) {
          break;
        }

        final pageResponse = await lookupProducts(
          productId: cleanId,
          market: market,
          languages: languages,
          top: pageSize,
          skip: skip,
          alternateId: alternateId,
        );

        if (pageResponse.isSuccess &&
            pageResponse.json is Map<String, dynamic>) {
          final pageMap = pageResponse.json as Map<String, dynamic>;
          rawPages.add(pageMap);
          extractFromPage(pageMap);

          // If no products were returned and hasMorePages is false, terminate early
          if (pageResponse.hasMorePages == false &&
              pageResponse.products.isEmpty) {
            break;
          }
        } else {
          // If a page fails or gets rate limited, retry once after a short backoff
          await Future.delayed(const Duration(milliseconds: 600));
          if (isCancelled?.call() == true) break;

          final retryResponse = await lookupProducts(
            productId: cleanId,
            market: market,
            languages: languages,
            top: pageSize,
            skip: skip,
            alternateId: alternateId,
          );
          if (retryResponse.isSuccess &&
              retryResponse.json is Map<String, dynamic>) {
            final pageMap = retryResponse.json as Map<String, dynamic>;
            rawPages.add(pageMap);
            extractFromPage(pageMap);
          }
        }

        final currentCandidateCount = (skip + pageSize) > totalCandidates
            ? totalCandidates
            : (skip + pageSize);

        onProgress?.call(
          currentCandidateCount,
          totalCandidates,
          mergedProducts.length,
        );
      }
    }

    stopwatch.stop();

    // Construct merged catalog JSON structure
    final mergedJson = <String, dynamic>{
      'TotalResultCount': totalCandidates,
      'HasMorePages': false,
      'BigIds': mergedBigIds.toList(),
      'ProductsCount': mergedProducts.length,
      'Products': mergedProducts,
      'PagesScraped': rawPages.length,
    };

    final mergedRawString = const JsonEncoder.withIndent(
      '  ',
    ).convert(mergedJson);
    final mergedParsedProducts = mergedProducts
        .map((p) => MicrosoftCatalogProduct.fromJson(p))
        .toList();

    return MicrosoftCatalogResponse(
      statusCode: 200,
      durationMs: stopwatch.elapsedMilliseconds,
      sizeBytes: mergedRawString.length,
      url:
          'https://$host/v7/products/lookup?value=$cleanId&market=$market&languages=$languages&\$top=$pageSize&alternateId=$alternateId (Scraped All)',
      json: mergedJson,
      rawString: mergedRawString,
      isSuccess: true,
      errorMessage: null,
      products: mergedParsedProducts,
      totalResultCount: totalCandidates,
      hasMorePages: false,
      bigIds: mergedBigIds.toList(),
      timestamp: DateTime.now(),
    );
  }

  /// Single search
  Future<MicrosoftCatalogResponse> getProductDetails({
    required String productId,
    String market = 'US',
    String languages = 'en-US',
  }) async {
    final cleanId = productId.trim();
    final queryParams = <String, String>{
      'languages': languages.trim().isEmpty ? 'en-US' : languages.trim(),
      'market': market.trim().isEmpty ? 'US' : market.trim(),
    };

    final uri = Uri.https(host, '/v7/products/$cleanId', queryParams);
    return _executeRequest(uri);
  }

  Future<MicrosoftCatalogResponse> rawRequest(String urlOrPath) async {
    final trimmed = urlOrPath.trim();
    final Uri uri;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      uri = Uri.parse(trimmed);
    } else {
      final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      uri = Uri.parse('https://$host$path');
    }
    return _executeRequest(uri);
  }

  Future<MicrosoftCatalogResponse> _executeRequest(Uri uri) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await AppHttpClient.instance
          .get(uri, headers: defaultHeaders)
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();

      return MicrosoftCatalogResponse.fromHttp(
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        url: uri.toString(),
        rawString: response.body,
        errorMessage: response.statusCode >= 400
            ? 'HTTP Error ${response.statusCode}: ${response.reasonPhrase ?? 'Request failed'}'
            : null,
      );
    } on TimeoutException {
      stopwatch.stop();
      return MicrosoftCatalogResponse.fromHttp(
        statusCode: 408,
        durationMs: stopwatch.elapsedMilliseconds,
        url: uri.toString(),
        rawString: '{"error": "Request timed out after 30 seconds"}',
        errorMessage: 'Request timed out after 30 seconds',
      );
    } catch (e) {
      stopwatch.stop();
      return MicrosoftCatalogResponse.fromHttp(
        statusCode: 500,
        durationMs: stopwatch.elapsedMilliseconds,
        url: uri.toString(),
        rawString:
            '{"error": "Network or client failure", "details": "${e.toString()}"}',
        errorMessage: e.toString(),
      );
    }
  }
}
