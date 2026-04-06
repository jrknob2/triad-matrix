import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/practice/practice_domain_v1.dart';

part 'app_state_store.g.dart';

class AppStateSnapshotData {
  final bool onboardingComplete;
  final UserProfileV1 profile;
  final List<PracticeItemV1> items;
  final List<PracticeCombinationV1> combinations;
  final PracticeRoutineV1 routine;
  final List<PracticeSessionLogV1> sessions;
  final List<CompetencyRecordV1> competencyRecords;

  const AppStateSnapshotData({
    required this.onboardingComplete,
    required this.profile,
    required this.items,
    required this.combinations,
    required this.routine,
    required this.sessions,
    required this.competencyRecords,
  });
}

@collection
class AppStateRecord {
  Id id = 0;
  int schemaVersion = 1;
  bool onboardingComplete = false;
  String profileJson = '{}';
  String itemsJson = '[]';
  String combinationsJson = '[]';
  String routineJson = '{}';
  String sessionsJson = '[]';
  String competencyJson = '[]';
}

class AppStateStore {
  AppStateStore._(this._isar);

  static const int currentSchemaVersion = 1;
  static const String _dbName = 'triad_trainer';
  final Isar _isar;

  static Future<AppStateStore> open() async {
    final dir = await getApplicationSupportDirectory();
    final isar = await Isar.open(
      <CollectionSchema<dynamic>>[AppStateRecordSchema],
      directory: dir.path,
      name: _dbName,
    );
    return AppStateStore._(isar);
  }

  Future<AppStateSnapshotData?> load() async {
    final AppStateRecord? record = await _isar.appStateRecords.get(0);
    if (record == null) return null;

    final Map<String, dynamic> profileMap =
        jsonDecode(record.profileJson) as Map<String, dynamic>;
    final List<dynamic> itemsList = jsonDecode(record.itemsJson) as List<dynamic>;
    final List<dynamic> combinationsList =
        jsonDecode(record.combinationsJson) as List<dynamic>;
    final Map<String, dynamic> routineMap =
        jsonDecode(record.routineJson) as Map<String, dynamic>;
    final List<dynamic> sessionsList =
        jsonDecode(record.sessionsJson) as List<dynamic>;
    final List<dynamic> competencyList =
        jsonDecode(record.competencyJson) as List<dynamic>;

    return AppStateSnapshotData(
      onboardingComplete: record.onboardingComplete,
      profile: _userProfileFromMap(profileMap),
      items: itemsList
          .map((dynamic item) => _practiceItemFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      combinations: combinationsList
          .map(
            (dynamic item) =>
                _practiceCombinationFromMap(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      routine: _practiceRoutineFromMap(routineMap),
      sessions: sessionsList
          .map(
            (dynamic item) =>
                _practiceSessionLogFromMap(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      competencyRecords: competencyList
          .map(
            (dynamic item) =>
                _competencyRecordFromMap(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  Future<void> save(AppStateSnapshotData snapshot) async {
    final AppStateRecord record = AppStateRecord()
      ..id = 0
      ..schemaVersion = currentSchemaVersion
      ..onboardingComplete = snapshot.onboardingComplete
      ..profileJson = jsonEncode(_userProfileToMap(snapshot.profile))
      ..itemsJson = jsonEncode(
        snapshot.items.map(_practiceItemToMap).toList(growable: false),
      )
      ..combinationsJson = jsonEncode(
        snapshot.combinations
            .map(_practiceCombinationToMap)
            .toList(growable: false),
      )
      ..routineJson = jsonEncode(_practiceRoutineToMap(snapshot.routine))
      ..sessionsJson = jsonEncode(
        snapshot.sessions.map(_practiceSessionLogToMap).toList(growable: false),
      )
      ..competencyJson = jsonEncode(
        snapshot.competencyRecords
            .map(_competencyRecordToMap)
            .toList(growable: false),
      );

    await _isar.writeTxn(() async {
      await _isar.appStateRecords.put(record);
    });
  }

  Map<String, dynamic> _userProfileToMap(UserProfileV1 profile) {
    return <String, dynamic>{
      'handedness': profile.handedness.name,
      'defaultBpm': profile.defaultBpm,
      'defaultTimerPreset': profile.defaultTimerPreset.name,
      'clickEnabledByDefault': profile.clickEnabledByDefault,
    };
  }

  UserProfileV1 _userProfileFromMap(Map<String, dynamic> map) {
    return UserProfileV1(
      handedness: HandednessV1.values.byName(map['handedness'] as String),
      defaultBpm: map['defaultBpm'] as int,
      defaultTimerPreset: TimerPresetV1.values.byName(
        map['defaultTimerPreset'] as String,
      ),
      clickEnabledByDefault: map['clickEnabledByDefault'] as bool,
    );
  }

  Map<String, dynamic> _practiceItemToMap(PracticeItemV1 item) {
    return <String, dynamic>{
      'id': item.id,
      'family': item.family.name,
      'name': item.name,
      'sticking': item.sticking,
      'noteCount': item.noteCount,
      'accentedNoteIndices': item.accentedNoteIndices,
      'ghostNoteIndices': item.ghostNoteIndices,
      'voiceAssignments': item.voiceAssignments.map((v) => v.name).toList(),
      'source': item.source.name,
      'tags': item.tags,
      'saved': item.saved,
    };
  }

  PracticeItemV1 _practiceItemFromMap(Map<String, dynamic> map) {
    return PracticeItemV1(
      id: map['id'] as String,
      family: MaterialFamilyV1.values.byName(map['family'] as String),
      name: map['name'] as String,
      sticking: map['sticking'] as String,
      noteCount: map['noteCount'] as int,
      accentedNoteIndices:
          (map['accentedNoteIndices'] as List<dynamic>).cast<int>(),
      ghostNoteIndices: (map['ghostNoteIndices'] as List<dynamic>).cast<int>(),
      voiceAssignments: (map['voiceAssignments'] as List<dynamic>)
          .map((dynamic value) => DrumVoiceV1.values.byName(value as String))
          .toList(growable: false),
      source: PracticeItemSourceV1.values.byName(map['source'] as String),
      tags: (map['tags'] as List<dynamic>).cast<String>(),
      saved: map['saved'] as bool,
    );
  }

  Map<String, dynamic> _practiceCombinationToMap(PracticeCombinationV1 combo) {
    return <String, dynamic>{
      'id': combo.id,
      'name': combo.name,
      'itemIds': combo.itemIds,
    };
  }

  PracticeCombinationV1 _practiceCombinationFromMap(Map<String, dynamic> map) {
    return PracticeCombinationV1(
      id: map['id'] as String,
      name: map['name'] as String,
      itemIds: (map['itemIds'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> _routineEntryToMap(RoutineEntryV1 entry) {
    return <String, dynamic>{
      'practiceItemId': entry.practiceItemId,
      'addedAt': entry.addedAt.toIso8601String(),
    };
  }

  RoutineEntryV1 _routineEntryFromMap(Map<String, dynamic> map) {
    return RoutineEntryV1(
      practiceItemId: map['practiceItemId'] as String,
      addedAt: DateTime.parse(map['addedAt'] as String),
    );
  }

  Map<String, dynamic> _practiceRoutineToMap(PracticeRoutineV1 routine) {
    return <String, dynamic>{
      'id': routine.id,
      'name': routine.name,
      'entries': routine.entries.map(_routineEntryToMap).toList(growable: false),
    };
  }

  PracticeRoutineV1 _practiceRoutineFromMap(Map<String, dynamic> map) {
    return PracticeRoutineV1(
      id: map['id'] as String,
      name: map['name'] as String,
      entries: (map['entries'] as List<dynamic>)
          .map((dynamic item) => _routineEntryFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> _practiceSessionLogToMap(PracticeSessionLogV1 session) {
    return <String, dynamic>{
      'id': session.id,
      'startedAt': session.startedAt.toIso8601String(),
      'endedAt': session.endedAt.toIso8601String(),
      'durationMs': session.duration.inMilliseconds,
      'practiceItemIds': session.practiceItemIds,
      'family': session.family.name,
      'practiceMode': session.practiceMode.name,
      'bpm': session.bpm,
      'clickEnabled': session.clickEnabled,
      'routineId': session.routineId,
      'reflection': session.reflection?.name,
    };
  }

  PracticeSessionLogV1 _practiceSessionLogFromMap(Map<String, dynamic> map) {
    return PracticeSessionLogV1(
      id: map['id'] as String,
      startedAt: DateTime.parse(map['startedAt'] as String),
      endedAt: DateTime.parse(map['endedAt'] as String),
      duration: Duration(milliseconds: map['durationMs'] as int),
      practiceItemIds: (map['practiceItemIds'] as List<dynamic>).cast<String>(),
      family: MaterialFamilyV1.values.byName(map['family'] as String),
      practiceMode: PracticeModeV1.values.byName(
        map['practiceMode'] as String,
      ),
      bpm: map['bpm'] as int,
      clickEnabled: map['clickEnabled'] as bool,
      routineId: map['routineId'] as String?,
      reflection: map['reflection'] == null
          ? null
          : ReflectionRatingV1.values.byName(map['reflection'] as String),
    );
  }

  Map<String, dynamic> _competencyRecordToMap(CompetencyRecordV1 record) {
    return <String, dynamic>{
      'practiceItemId': record.practiceItemId,
      'level': record.level.name,
      'updatedAt': record.updatedAt.toIso8601String(),
    };
  }

  CompetencyRecordV1 _competencyRecordFromMap(Map<String, dynamic> map) {
    return CompetencyRecordV1(
      practiceItemId: map['practiceItemId'] as String,
      level: CompetencyLevelV1.values.byName(map['level'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
