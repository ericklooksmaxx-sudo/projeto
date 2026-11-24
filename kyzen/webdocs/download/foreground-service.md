# Foreground Download Service

Operates an Android Foreground Service using the `flutter_foreground_task` library. This prevents the OS from suspending the application while processing downloads.

## Foreground Task Options

- **Notification Channel:** Registers `foreground_download_service` channel to display persistent notification icons and progress.
- **Locks:** Requests Android WiFi Lock (`allowWifiLock`) from going to sleep during downloads.
- **Service Type:** Registered as a `dataSync` service, complying with Android 14+ background execution guidelines.

## Service Code

```dart
await FlutterForegroundTask.startService(
  serviceId: 256,
  serviceTypes: [ForegroundServiceTypes.dataSync],
  notificationTitle: "Downloading DLC...",
  notificationText: "Progress: 45%",
  callback: startDownloadCallback
);
```
