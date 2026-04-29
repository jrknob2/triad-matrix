import 'package:drumcabulary/state/persistence/app_state_store.dart';

class FakeAppStateStore implements AppStateStore {
  FakeAppStateStore({this.initialSnapshot, this.onSave});

  final AppStateSnapshotData? initialSnapshot;
  final Future<void> Function(AppStateSnapshotData snapshot)? onSave;

  int saveCount = 0;
  final List<AppStateSnapshotData> savedSnapshots = <AppStateSnapshotData>[];

  @override
  Future<AppStateSnapshotData?> load() async => initialSnapshot;

  @override
  Future<void> save(AppStateSnapshotData snapshot) async {
    saveCount += 1;
    savedSnapshots.add(snapshot);
    await onSave?.call(snapshot);
  }
}
