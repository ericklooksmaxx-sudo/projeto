# Download Service

Coordinates download queues, manages progress reports, and triggers the decryption pipeline on successful completion.

## Queue and Task Execution

- Downloads are encapsulated into `DownloadTask` models and appended to a queue.
- Downloads are processed sequentially (one task at a time).
- **MD5 Checksum Verification:** Reads the HTTP response header `content-md5`, computes the MD5 hash during chunk streams, and verifies that the hashes match to ensure file integrity.

## Platform Download Fallbacks

Because mobile devices restrict standard HTTP background tasks, DownloadService operates two download branches:

- **Android:** Delegates downloads to the native platform via `NativeDownloader` to ensure persistence in background states.
- **Windows / Linux:** Uses a standard HTTP client.
