# Changelog

## Unreleased

## 1.1.0

* Add methods for attaching to existing instances of the DatadogSdk for "add-to-app" scenarios.
* Add `addUserExtraInfo` method for providing extra user attributes without overwriting other user info. See [#254][]
* Add `RumConfiguration.vitalUpdateFrequency` to allow control over how often the Native SDKs query for vitals (CPU and memory usage).
* Fix a crash caused by attempting to send logs while an app was terminating See [#271][]

## 1.0.1

* Update Android SDK to 1.14.1
  * Add CPU architecture to the collected device information.

## 1.0.0

* Deprecation - `DdSdkConfiguration.customEndpoint` has been deprecated in favor of `DdSdkConfiguration.customLogsEndpoint` and `RumConfiguration.customEndpoint`.
* Added `DdSdkConfiguration.version` configuration option for specifying a custom application version.
* Fix `null` values in attributes not being correctly encoded on iOS.
* Add `flavor` as a configuration parameter.
* Updated iOS SDK to 1.12.0
* Updated Android SDK to 1.14.0

## 1.0.0-rc.3

* 🔥 MAJOR - Fixed an issue on Android where Datadog would not properly reinitialize after backing out of an application (pressing the back button on the home screen) and returning to it.
* Fix Flutter 3 log spam regarding use of `?.` on WidgetBindings.instance. See [#203][]
* Sync long task threshold between Flutter and Native long task reporting.
* Fix an issue where events that contained lists from `dart:typed_data` (`Float32List`, `Uint8List`, etc) were not being encoded / sent on iOS.
* Update iOS SDK to 1.12.0-beta3

## 1.0.0-rc.2

* Fix an issue with using `WidgetBindings.instance` as a non-optional (Property is optional pre-Flutter 3.0)

## 1.0.0-rc.1

* Update Android SDK to 1.14.0-beta1
* Update iOS SDK to 1.12.0-beta2
  * Include the exact model information in RUM `device.model`. Also fixes [#133][]
* Remove deprecated tracing feature.
* Removed `RumHttpMethod.unknown` as it is translated GET on the native side anyway.
* Added Long Task reporting.

## 1.0.0-beta.3

* Update Android SDK to 1.13.0-rc1
  * Improve local LogCat messages from the SDK.
  * Disables vitals collection when app is in the background.
  * Fix updating Global RUM context when a view is stopped.
  * For a full list of changes see the [Android Changelog](https://github.com/DataDog/dd-sdk-android/blob/develop/CHANGELOG.md#1130--2022-05-24).
* Update iOS SDK to 1.11.0
  * For a full list of changes see the [iOS Changelog](https://github.com/DataDog/dd-sdk-ios/blob/develop/CHANGELOG.md#1110--13-06-2022)
* Made analysis rules stricter and switched several attribute map parameters from `Map<String, dynamic>` to `Map<String, Object?>` for better compatibility with `implicit-dynamic: false` See [#143][] and [#148][]
* Fix `serviceName` configuration parameter [#159][]

## 1.0.0-beta.2

* Update iOS SDK to 1.11-rc1
  * Allow manually tracked resources in RUM Sessions to detect first party hosts.
  * Better error message when encountering an invalid token (Fixes #117).
  * Fix RUM events to support configured `source` property.
  * For a full list of changes, see the [iOS Changelog](https://github.com/DataDog/dd-sdk-ios/blob/develop/CHANGELOG.md#1110-rc1--18-05-2022).
* Added `datadogReportingThreshold` to `LoggingConfiguration` to support only sending logs above a certain threshold to Datadog.
* Add support for setting a tracing sample rate for RUM.
* Expose `DdLogs` through the main package import. Added documentation to DdLogs.
* Added initial Flutter Web features and tests. Note: Flutter Web is not ready for production use.

## 1.0.0-beta.1

* Update iOS SDK to 1.11-beta2
  * Stop reporting pre-warmed application launch time.
  * Reduce the number of intermediate view events sent in RUM payloads.
  * For a full list of changes, see the [iOS Changelog](https://github.com/DataDog/dd-sdk-ios/blob/develop/CHANGELOG.md#1110-beta1--04-26-2022).
* Send `firstPartyHosts` to Native SDKs during initialization. Make
  `firstPartyHosts` property on read only `DatadogSdk` read only. 
* 💥 Breaking! - Deprecated non-RUM resource tracing.
* Properly report `source` as Flutter on iOS.

## 1.0.0-alpha.2

* Cancel spans on DatadogTrackingHttpClient when RUM is enabled (prevent spans
  from leaking native resources)
* Remove native view tracking (Activities and Fragments) from Android by default
* Add support for creating multiple named loggers: `DatadogSdk.createLogger` and
  `LoggingConfiguration.loggerName`
* Add support for configuring whether loggers send data to Datadog:
  `LoggingConfiguration.sendLogsToDatadog`
* 💥 Breaking! - Removed `DdSdkConfiguration.trackHttpClient`. This has been
  replaced with a standalone `datadog_tracking_http_client` package.
* 💥 Breaking! - `DdSdkConfiguration.site` is now a required parameter and no
  longer defaults to `DatadogSite.us1`

## 1.0.0-alpha.1

* Support for Logging, Tracing (including Datadog Distributed Tracing) and RUM
  * iOS Support with Datadog SDK for iOS 1.9.0
  * Android Support with Datadog SDK for Android 1.12.0-alpha2
* Automatically track network requests with `DatadogTrackingHttpClient`
* Error reporting for iOS, Android, and Android NDK crashes.

[#133]: https://github.com/DataDog/dd-sdk-flutter/issues/133
[#143]: https://github.com/DataDog/dd-sdk-flutter/issues/143
[#148]: https://github.com/DataDog/dd-sdk-flutter/issues/148
[#159]: https://github.com/DataDog/dd-sdk-flutter/issues/159
[#203]: https://github.com/DataDog/dd-sdk-flutter/issues/203
[#254]: https://github.com/DataDog/dd-sdk-flutter/issues/254
[#271]: https://github.com/DataDog/dd-sdk-flutter/issues/271
