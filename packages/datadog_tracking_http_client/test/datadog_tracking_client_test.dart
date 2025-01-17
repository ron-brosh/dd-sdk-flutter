// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';
import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_tracking_http_client/src/tracking_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'test_utils.dart';

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDdRum extends Mock implements DdRum {}

class MockClient extends Mock implements http.Client {}

class MockStreamedResponse extends Mock implements http.StreamedResponse {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

void main() {
  late MockDatadogSdk mockDatadog;
  late MockClient mockClient;
  late MockStreamedResponse mockResponse;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(FakeBaseRequest());
  });

  setUp(() {
    mockDatadog = MockDatadogSdk();
    when(() => mockDatadog.isFirstPartyHost(
        any(that: HasHost(equals('test_url'))))).thenReturn(true);
    when(() => mockDatadog.isFirstPartyHost(
        any(that: HasHost(equals('non_first_party'))))).thenReturn(false);

    mockResponse = MockStreamedResponse();
    when(() => mockResponse.stream)
        .thenAnswer((_) => http.ByteStream.fromBytes([]));
    when(() => mockResponse.statusCode).thenReturn(200);
    when(() => mockResponse.persistentConnection).thenReturn(false);
    when(() => mockResponse.request).thenReturn(FakeBaseRequest());
    when(() => mockResponse.headers).thenReturn({});
    when(() => mockResponse.isRedirect).thenReturn(false);

    mockClient = MockClient();
    when(() => mockClient.send(any()))
        .thenAnswer((_) => Future.value(mockResponse));
  });

  group('when rum is disabled', () {
    setUp(() {
      when(() => mockDatadog.rum).thenReturn(null);
    });

    test('tracking client passes through send calls', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');
      final response =
          await client.get(testUri, headers: {'x-datadog-header': 'header'});

      final captured = verify(() => mockClient.send(captureAny())).captured[0]
          as http.BaseRequest;
      expect(captured.url, testUri);
      expect(captured.headers, {'x-datadog-header': 'header'});
    });
  });

  group('when rum is enabled', () {
    late MockDdRum mockRum;

    setUp(() {
      mockRum = MockDdRum();
      when(() => mockRum.shouldSampleTrace()).thenReturn(true);
      when(() => mockRum.tracingSamplingRate).thenReturn(50.0);

      when(() => mockDatadog.rum).thenReturn(mockRum);
    });

    test('calls startResourceLoading on initial request', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');
      final _ = client.get(testUri, headers: {'x-datadog-header': 'header'});

      verify(() => mockRum.startResourceLoading(
          any(), RumHttpMethod.get, testUri.toString(), any()));
    });

    test('adds tracing headers to request', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');
      final _ = client.get(testUri, headers: {'x-datadog-header': 'header'});

      final captured = verify(() => mockClient.send(captureAny())).captured[0]
          as http.BaseRequest;
      expect(captured.url, testUri);

      final headers = captured.headers;
      expect(headers['x-datadog-header'], 'header');
      expect(headers['x-datadog-sampling-priority'], '1');

      final traceValue = headers['x-datadog-trace-id'];
      final traceInt = traceValue != null ? BigInt.tryParse(traceValue) : null;
      expect(traceInt, isNotNull);
      expect(traceInt?.bitLength, lessThanOrEqualTo(63));

      final spanValue = headers['x-datadog-parent-id'];
      final spanInt = spanValue != null ? BigInt.tryParse(spanValue) : null;
      expect(spanInt, isNotNull);
      expect(spanInt?.bitLength, lessThanOrEqualTo(63));
    });

    test('adds tracing attributes to startResourceLoading', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');
      final _ = client.get(testUri, headers: {'x-datadog-header': 'header'});

      final callAttributes = verify(() => mockRum.startResourceLoading(
              any(), RumHttpMethod.get, testUri.toString(), captureAny()))
          .captured[0] as Map<String, Object?>;

      final traceValue = callAttributes['_dd.trace_id'] as String?;
      final traceInt = traceValue != null ? BigInt.tryParse(traceValue) : null;
      expect(traceInt, isNotNull);
      expect(traceInt?.bitLength, lessThanOrEqualTo(63));

      final spanValue = callAttributes['_dd.span_id'] as String?;
      final spanInt = spanValue != null ? BigInt.tryParse(spanValue) : null;
      expect(spanInt, isNotNull);
      expect(spanInt?.bitLength, lessThanOrEqualTo(63));
    });

    test('calls stopResourceLoading on completion', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');
      final future =
          client.get(testUri, headers: {'x-datadog-header': 'header'});

      final response = await future;

      final key = verify(() => mockRum.startResourceLoading(
              captureAny(), RumHttpMethod.get, testUri.toString(), any()))
          .captured[0] as String;

      verify(() => mockRum.stopResourceLoading(
          key, 200, RumResourceType.native, any(), any()));
    });

    test('calls stopResourceLoading with size and deduced content type',
        () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');

      when(() => mockResponse.contentLength).thenReturn(88888);
      when(() => mockResponse.headers).thenReturn({
        HttpHeaders.contentTypeHeader: ContentType('image', 'png').toString()
      });
      final future =
          client.get(testUri, headers: {'x-datadog-header': 'header'});

      final response = await future;

      final key = verify(() => mockRum.startResourceLoading(
              captureAny(), RumHttpMethod.get, testUri.toString(), any()))
          .captured[0] as String;

      verify(() => mockRum.stopResourceLoading(
          key, 200, RumResourceType.image, 88888, any()));
    });

    test(
        'send throwingError rethrows and calls stopResourceLoadingWithErrorInfo',
        () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');

      final errorToThrow = Error();
      Object? thrownError;
      when(() => mockClient.send(any())).thenThrow(errorToThrow);
      try {
        final _ =
            await client.get(testUri, headers: {'x-datadog-header': 'header'});
      } catch (e) {
        thrownError = e;
      }

      final key = verify(() => mockRum.startResourceLoading(
              captureAny(), RumHttpMethod.get, testUri.toString(), any()))
          .captured[0] as String;

      expect(thrownError, thrownError);
      verify(() => mockRum.stopResourceLoadingWithErrorInfo(
          key, thrownError.toString(), thrownError.runtimeType.toString()));
    });

    test('passes through stream data', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');

      final errorToThrow = Error();
      final streamController = StreamController<List<int>>();
      Object? thrownError;
      when(() => mockResponse.stream).thenAnswer(
          (_) => http.ByteStream.fromBytes([1, 2, 3, 4, 5, 122, 121, 120]));

      final response =
          await client.get(testUri, headers: {'x-datadog-header': 'header'});

      expect(response.bodyBytes.toList(), [1, 2, 3, 4, 5, 122, 121, 120]);
    });

    test('error in stream and calls stopResourceLoadingWithErrorInfo',
        () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');

      final errorToThrow = Error();
      final streamController = StreamController<List<int>>();
      Object? thrownError;
      when(() => mockResponse.stream)
          .thenAnswer((_) => http.ByteStream(streamController.stream));

      final future =
          client.get(testUri, headers: {'x-datadog-header': 'header'});

      try {
        streamController.sink.addError(errorToThrow);

        await future;
      } catch (e) {
        thrownError = e;
      }

      expect(errorToThrow, thrownError);
      final key = verify(() => mockRum.startResourceLoading(
              captureAny(), RumHttpMethod.get, testUri.toString(), any()))
          .captured[0] as String;

      verify(() => mockRum.stopResourceLoadingWithErrorInfo(
          key, errorToThrow.toString(), errorToThrow.runtimeType.toString()));
    });

    test('does not trace 3rd party requests', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://non_first_party/test');
      final _ = client.get(testUri, headers: {'x-datadog-header': 'header'});

      final captured = verify(() => mockClient.send(captureAny())).captured[0]
          as http.BaseRequest;
      expect(captured.url, testUri);

      final headers = captured.headers;
      expect(headers['x-datadog-header'], 'header');
      expect(headers['x-datadog-sampling-priority'], isNull);
      expect(headers['x-datadog-trace-id'], isNull);
      expect(headers['x-datadog-parent-id'], isNull);

      final callAttributes = verify(() => mockRum.startResourceLoading(
              any(), RumHttpMethod.get, testUri.toString(), captureAny()))
          .captured[0] as Map<String, Object?>;
      expect(callAttributes['_dd.trace_id'], isNull);
      expect(callAttributes['_dd.parent_id'], isNull);
    });
  });
}
