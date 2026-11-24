class EntitlementResult {
  final List<ProcessedFile> successfulFiles;
  final List<FailedFile> failedFiles;
  final List<String> errors;
  final int totalKeysExtracted;

  EntitlementResult({
    required this.successfulFiles,
    required this.failedFiles,
    required this.errors,
    required this.totalKeysExtracted,
  });

  bool get hasErrors => errors.isNotEmpty || failedFiles.isNotEmpty;
  bool get hasSuccess => successfulFiles.isNotEmpty;
}

class ProcessedFile {
  final String filePath;
  final int keysExtracted;

  ProcessedFile({required this.filePath, required this.keysExtracted});
}

class FailedFile {
  final String filePath;
  final String reason;

  FailedFile({required this.filePath, required this.reason});
}
