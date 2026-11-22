// Pure Last-Write-Wins (LWW) record merger for 2-way iOS <-> Android sync.

abstract final class SyncMerger {
  static List<T> mergeByUpdatedAt<T>({
    required List<T> local,
    required List<T> remote,
    required String Function(T item) idOf,
    required DateTime Function(T item) updatedAtOf,
  }) {
    final merged = <String, T>{
      for (final item in local) idOf(item): item,
    };

    for (final remoteItem in remote) {
      final id = idOf(remoteItem);
      final existing = merged[id];
      if (existing == null ||
          updatedAtOf(remoteItem).isAfter(updatedAtOf(existing))) {
        merged[id] = remoteItem;
      }
    }

    return merged.values.toList(growable: false);
  }
}
