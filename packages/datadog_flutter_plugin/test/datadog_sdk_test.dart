// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_flutter_plugin/src/datadog_sdk_platform_interface.dart';
import 'package:datadog_flutter_plugin/src/logs/ddlogs_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDatadogSdkPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSdkPlatform {}

class MockDdLogsPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DdLogsPlatform {}

class FakeDdSdkConfiguration extends Fake implements DdSdkConfiguration {}

class MockDatadogPluginConfiguration extends Mock
    implements DatadogPluginConfiguration {}

class MockDatadogPlugin extends Mock implements DatadogPlugin {}

void main() {
  late DatadogSdk datadogSdk;
  late MockDatadogSdkPlatform mockPlatform;
  late MockDdLogsPlatform mockLogsPlatform;

  setUpAll(() {
    registerFallbackValue(FakeDdSdkConfiguration());
    registerFallbackValue(TrackingConsent.granted);
    registerFallbackValue(LoggingConfiguration());
  });

  setUp(() {
    mockPlatform = MockDatadogSdkPlatform();
    when(() => mockPlatform.initialize(any(),
            logCallback: any(named: 'logCallback')))
        .thenAnswer((_) => Future<void>.value());
    when(() => mockPlatform.attachToExisting())
        .thenAnswer((_) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: false,
            )));
    when(() => mockPlatform.setUserInfo(any(), any(), any(), any()))
        .thenAnswer((_) => Future<void>.value());
    when(() => mockPlatform.addUserExtraInfo((any())))
        .thenAnswer((_) => Future<void>.value());
    when(() => mockPlatform.setTrackingConsent(any()))
        .thenAnswer((_) => Future<void>.value());
    when(() => mockPlatform.flushAndDeinitialize())
        .thenAnswer((_) => Future<void>.value());
    DatadogSdkPlatform.instance = mockPlatform;
    datadogSdk = DatadogSdk.instance;

    mockLogsPlatform = MockDdLogsPlatform();
    DdLogsPlatform.instance = mockLogsPlatform;
  });

  tearDown(() async {
    await datadogSdk.flushAndDeinitialize();
  });

  test('initialize passes configuration to platform', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
    );
    await datadogSdk.initialize(configuration);

    verify(() => mockPlatform.initialize(configuration,
        logCallback: any(named: 'logCallback')));
  });

  test('encode base configuration', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fake-client-token',
      env: 'prod',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
    );
    final encoded = configuration.encode();
    expect(encoded, {
      'clientToken': 'fake-client-token',
      'env': 'prod',
      'site': 'DatadogSite.us1',
      'serviceName': null,
      'nativeCrashReportEnabled': false,
      'trackingConsent': 'TrackingConsent.pending',
      'telemetrySampleRate': null,
      'customLogsEndpoint': null,
      'batchSize': null,
      'uploadFrequency': null,
      'firstPartyHosts': <String>[],
      'rumConfiguration': null,
      'additionalConfig': <String, Object?>{},
    });
  });

  test('initialize encoding serializes enums correctly', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'environment',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.granted,
    )
      ..batchSize = BatchSize.small
      ..uploadFrequency = UploadFrequency.frequent
      ..site = DatadogSite.eu1;

    final encoded = configuration.encode();
    expect(encoded['batchSize'], 'BatchSize.small');
    expect(encoded['uploadFrequency'], 'UploadFrequency.frequent');
    expect(encoded['site'], 'DatadogSite.eu1');
  });

  test('configuration encodes telemetrySampleRate', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fake-client-token',
      env: 'prod',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      telemetrySampleRate: 21.0,
    );
    final encoded = configuration.encode();
    expect(encoded['telemetrySampleRate'], 21.0);
  });

  test('configuration encodes serviceName', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      serviceName: 'com.servicename',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.notGranted,
    );

    final encoded = configuration.encode();
    // Logging configuration is purposefully not encoded
    expect(encoded['serviceName'], 'com.servicename');
  });

  test('version added to additionalConfiguration', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.notGranted,
      version: '1.9.8+123',
    );

    final encoded = configuration.encode();
    final additionalConfig =
        encoded['additionalConfig'] as Map<String, Object?>;
    expect(additionalConfig[DatadogConfigKey.version], '1.9.8-123');
  });

  test('flavor added to additionalConfiguration', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.notGranted,
      flavor: 'strawberry',
    );

    final encoded = configuration.encode();
    final additionalConfig =
        encoded['additionalConfig'] as Map<String, Object?>;
    expect(additionalConfig[DatadogConfigKey.variant], 'strawberry');
  });

  test('configuration encodes default sub-configuration', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.notGranted,
      loggingConfiguration: LoggingConfiguration(),
      rumConfiguration: RumConfiguration(
        applicationId: 'fake-application-id',
        vitalUpdateFrequency: VitalsFrequency.frequent,
      ),
    );

    final encoded = configuration.encode();
    // Logging configuration is purposefully not encoded
    expect(encoded['loggingConfiguration'], isNull);
    expect(
        encoded['rumConfiguration'], configuration.rumConfiguration?.encode());
  });

  test('initialize with logging configuration creates logger', () async {
    when(() => mockLogsPlatform.createLogger(any(), any()))
        .thenAnswer((_) => Future<void>.value());

    final loggingConfiguration = LoggingConfiguration();
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      loggingConfiguration: loggingConfiguration,
    );
    await datadogSdk.initialize(configuration);

    final logger = datadogSdk.logs;

    expect(logger, isNotNull);
    verify(() => mockLogsPlatform.createLogger(
        logger!.loggerHandle, loggingConfiguration));
  });

  test('attachToExisting calls out to platform', () async {
    await datadogSdk.attachToExisting(DdSdkExistingConfiguration());

    verify(() => mockPlatform.attachToExisting());
    expect(datadogSdk.rum, isNull);
    expect(datadogSdk.logs, isNull);
  });

  test('attachToExisting forwards creation firstPartyHosts', () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: false,
            )));

    await datadogSdk.attachToExisting(DdSdkExistingConfiguration(
      firstPartyHosts: ['example.com', 'datadoghq.com'],
    ));

    expect(datadogSdk.firstPartyHosts, ['example.com', 'datadoghq.com']);
  });

  test('attachToExisiting with loggingConfiguration creates default logger',
      () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: false,
            )));
    when(() => mockLogsPlatform.createLogger(any(), any()))
        .thenAnswer((_) => Future<void>.value());
    final logConfig = LoggingConfiguration();

    await datadogSdk.attachToExisting(
      DdSdkExistingConfiguration(
        loggingConfiguration: logConfig,
        detectLongTasks: false,
      ),
    );

    expect(datadogSdk.logs, isNotNull);
    verify(() => mockLogsPlatform.createLogger(any(), logConfig));
  });

  test('attachToExisiting without loggingConfiguration does not create logger',
      () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: false,
            )));

    await datadogSdk.attachToExisting(DdSdkExistingConfiguration(
      detectLongTasks: false,
    ));
    expect(datadogSdk.logs, null);
  });

  test('attachToExisting with rumEnabled creates RUM bridge', () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: true,
            )));

    await datadogSdk.attachToExisting(DdSdkExistingConfiguration(
      detectLongTasks: false,
    ));
    expect(datadogSdk.rum, isNotNull);
  });

  test('attachToExisting with rumEnabled forwards RUM parameters', () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: true,
            )));

    await datadogSdk.attachToExisting(DdSdkExistingConfiguration(
      longTaskThreshold: 0.5,
      tracingSamplingRate: 100.0,
      detectLongTasks: false,
    ));

    expect(datadogSdk.rum?.configuration.longTaskThreshold, 0.5);
    expect(datadogSdk.rum?.configuration.tracingSamplingRate, 100.0);
  });

  test('first party hosts get set to sdk', () async {
    var firstPartyHosts = ['example.com', 'datadoghq.com'];

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: firstPartyHosts,
    );
    await datadogSdk.initialize(configuration);

    expect(datadogSdk.firstPartyHosts, firstPartyHosts);
  });

  test('first party hosts are encoded', () async {
    var firstPartyHosts = ['example.com', 'datadoghq.com'];

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: firstPartyHosts,
    );

    final encoded = configuration.encode();
    expect(encoded['firstPartyHosts'], firstPartyHosts);
  });

  test('isFirstPartyHost with no hosts returns false', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
    );
    await datadogSdk.initialize(configuration);

    var uri = Uri.parse('https://first_party');
    expect(datadogSdk.isFirstPartyHost(uri), isFalse);
  });

  test('isFirstPartyHost with matching host returns true', () async {
    var firstPartyHosts = ['example.com', 'datadoghq.com'];

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: firstPartyHosts,
    );
    await datadogSdk.initialize(configuration);

    var uri = Uri.parse('https://datadoghq.com/path');
    expect(datadogSdk.isFirstPartyHost(uri), isTrue);
  });

  test('isFirstPartyHost with matching host with subdomain returns true',
      () async {
    var firstPartyHosts = ['example.com', 'datadoghq.com'];

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: firstPartyHosts,
    );
    await datadogSdk.initialize(configuration);

    var uri = Uri.parse('https://test.datadoghq.com/path');
    expect(datadogSdk.isFirstPartyHost(uri), isTrue);
  });

  test('isFirstPartyHost with matching subdomain does not match root',
      () async {
    var firstPartyHosts = ['example.com', 'test.datadoghq.com'];

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: firstPartyHosts,
    );
    await datadogSdk.initialize(configuration);

    var uri = Uri.parse('https://datadoghq.com/path');
    expect(datadogSdk.isFirstPartyHost(uri), isFalse);
  });

  test('isFirstPartyHost escapes special characters in hosts', () async {
    var firstPartyHosts = ['test.datadoghq.com'];

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: firstPartyHosts,
    );
    await datadogSdk.initialize(configuration);

    var uri = Uri.parse('https://testdatadoghq.com/path');
    expect(datadogSdk.isFirstPartyHost(uri), isFalse);
  });

  test('set user info calls into platform', () {
    datadogSdk.setUserInfo(
        id: 'fake_id', name: 'fake_name', email: 'fake_email');

    verify(() =>
        mockPlatform.setUserInfo('fake_id', 'fake_name', 'fake_email', {}));
  });

  test('set user info calls into platform passing extraInfo', () {
    datadogSdk.setUserInfo(
      id: 'fake_id',
      name: 'fake_name',
      email: 'fake_email',
      extraInfo: {'attribute': 32.0},
    );

    verify(() => mockPlatform.setUserInfo(
          'fake_id',
          'fake_name',
          'fake_email',
          {'attribute': 32.0},
        ));
  });

  test('set user info calls into platform passing null values', () {
    datadogSdk.setUserInfo(id: null, name: null, email: null);

    verify(() => mockPlatform.setUserInfo(null, null, null, {}));
  });

  test('addUserExtraInfo passes through to platform', () {
    datadogSdk.addUserExtraInfo({
      'example_1': 'test',
      'example_2': null,
    });

    verify(() => mockPlatform.addUserExtraInfo({
          'example_1': 'test',
          'example_2': null,
        }));
  });

  test('set tracking consent calls into platform', () {
    datadogSdk.setTrackingConsent(TrackingConsent.notGranted);

    verify(() => mockPlatform.setTrackingConsent(TrackingConsent.notGranted));
  });

  test('createLogger calls into logs platform', () {
    when(() => mockLogsPlatform.createLogger(any(), any()))
        .thenAnswer((_) => Future<void>.value());
    final config = LoggingConfiguration(loggerName: 'test_logger');

    final logger = datadogSdk.createLogger(config);

    expect(logger, isNotNull);
    verify(() => mockLogsPlatform.createLogger(logger.loggerHandle, config));
  });

  test('plugin added to configuration is created during initialization',
      () async {
    final mockPluginConfig = MockDatadogPluginConfiguration();
    final mockPlugin = MockDatadogPlugin();
    when(() => mockPluginConfig.create(datadogSdk))
        .thenAnswer((_) => mockPlugin);

    final config = DdSdkConfiguration(
      clientToken: 'fake_token',
      env: 'env',
      trackingConsent: TrackingConsent.granted,
      site: DatadogSite.us1,
    )..addPlugin(mockPluginConfig);

    await datadogSdk.initialize(config);

    verify(() => mockPluginConfig.create(datadogSdk));
    verify(() => mockPlugin.initialize());
    expect(datadogSdk.getPlugin<MockDatadogPlugin>(), mockPlugin);
  });

  test('plugin added to configuration is created during attachToExisting',
      () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: false,
            )));

    final mockPluginConfig = MockDatadogPluginConfiguration();
    final mockPlugin = MockDatadogPlugin();
    when(() => mockPluginConfig.create(datadogSdk))
        .thenAnswer((_) => mockPlugin);

    final config = DdSdkExistingConfiguration()..addPlugin(mockPluginConfig);

    await datadogSdk.attachToExisting(config);

    verify(() => mockPluginConfig.create(datadogSdk));
    verify(() => mockPlugin.initialize());
    expect(datadogSdk.getPlugin<MockDatadogPlugin>(), mockPlugin);
  });
}
