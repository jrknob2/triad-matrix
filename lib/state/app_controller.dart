import 'package:flutter/foundation.dart';

import '../core/pattern/triad_matrix.dart';
import '../core/practice/practice_domain_v1.dart';
import '../features/app/app_formatters.dart';

class AppController extends ChangeNotifier {
  AppController() {
    _seed();
  }

  late UserProfileV1 _profile;
  late List<PracticeItemV1> _items;
  late List<PracticeCombinationV1> _combinations;
  late PracticeRoutineV1 _routine;
  late List<PracticeSessionLogV1> _sessions;
  late Map<String, CompetencyRecordV1> _competencyByItemId;
  bool _onboardingComplete = false;
  int _resetVersion = 0;

  UserProfileV1 get profile => _profile;
  List<PracticeItemV1> get items => List<PracticeItemV1>.unmodifiable(_items);
  List<PracticeCombinationV1> get combinations =>
      List<PracticeCombinationV1>.unmodifiable(_combinations);
  PracticeRoutineV1 get routine => _routine;
  bool get onboardingComplete => _onboardingComplete;
  int get resetVersion => _resetVersion;

  String get weakHandLabel =>
      _profile.handedness == HandednessV1.right ? 'Left' : 'Right';

  String get strongHandLabel =>
      _profile.handedness == HandednessV1.right ? 'Right' : 'Left';

  List<PracticeSessionLogV1> get recentSessions {
    final List<PracticeSessionLogV1> copy = List<PracticeSessionLogV1>.from(
      _sessions,
    );
    copy.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return List<PracticeSessionLogV1>.unmodifiable(copy);
  }

  List<PracticeItemV1> get triadMatrixItems {
    return triadMatrixAll()
        .map((cell) => itemById(_triadItemId(cell.id)))
        .toList(growable: false);
  }

  TodayBriefingV1 buildTodayBriefing() {
    final List<PracticeItemV1> weakHandItems =
        triadMatrixItems.where(_isWeakHandLead).toList(growable: false)
          ..sort(_compareByNeed);

    final List<PracticeItemV1> neglectedTriads = triadMatrixItems.toList()
      ..sort(_compareByNeed);

    final List<PracticeItemV1> almostReady =
        triadMatrixItems
            .where((item) {
              final CompetencyLevelV1 competency = competencyFor(item.id);
              return competency == CompetencyLevelV1.comfortable ||
                  competency == CompetencyLevelV1.reliable;
            })
            .toList(growable: false)
          ..sort(
            (a, b) =>
                totalTime(itemId: b.id).compareTo(totalTime(itemId: a.id)),
          );

    final List<PracticeItemV1> accentItems =
        triadMatrixItems
            .where((item) => item.hasAccents && !usesKick(item.id))
            .toList(growable: false)
          ..sort(_compareByNeed);

    return TodayBriefingV1(
      headline: 'Today leans toward control, touch, and flow.',
      summary:
          '$weakHandLabel-hand lead needs attention, a few triads are close to toolbox status, and there is room for fresh material.',
      cues: <CoachCueV1>[
        CoachCueV1(
          title: 'Weak Hand',
          detail:
              '$weakHandLabel-hand lead is under-practiced. Start there while your hands are fresh.',
          suggestedItemIds: weakHandItems
              .take(2)
              .map((item) => item.id)
              .toList(),
        ),
        CoachCueV1(
          title: 'New Ground',
          detail:
              'A few triads have barely been touched lately. Add one new cell to the routine.',
          suggestedItemIds: neglectedTriads
              .take(2)
              .map((item) => item.id)
              .toList(),
        ),
        CoachCueV1(
          title: 'Close To Toolbox',
          detail:
              'These are nearly reliable. Tighten them up and they can move into your toolbox.',
          suggestedItemIds: almostReady.take(2).map((item) => item.id).toList(),
        ),
        CoachCueV1(
          title: 'Accent Focus',
          detail:
              'Accent placement matters. These cells are good candidates for deliberate accent work.',
          suggestedItemIds: accentItems.take(2).map((item) => item.id).toList(),
        ),
      ],
    );
  }

  List<PracticeItemV1> itemsByFamily(MaterialFamilyV1 family) {
    final List<PracticeItemV1> filtered = _items
        .where((item) => item.family == family)
        .toList(growable: false);
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  List<PracticeItemV1> sourceItemsForBuilder() {
    final List<PracticeItemV1> filtered = _items
        .where((item) => item.family != MaterialFamilyV1.combo)
        .toList(growable: false);
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  PracticeItemV1 itemById(String id) {
    return _items.firstWhere((item) => item.id == id);
  }

  PracticeItemV1? itemByIdOrNull(String id) {
    for (final PracticeItemV1 item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  PracticeItemV1? triadItemForCell(String cellId) {
    return itemByIdOrNull(_triadItemId(cellId));
  }

  PracticeSessionLogV1? sessionById(String id) {
    for (final PracticeSessionLogV1 session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  CompetencyLevelV1 competencyFor(String itemId) {
    return _competencyByItemId[itemId]?.level ?? CompetencyLevelV1.notStarted;
  }

  bool isDirectRoutineEntry(String itemId) {
    return _routine.entries.any((entry) => entry.practiceItemId == itemId);
  }

  bool isInRoutine(String itemId) {
    return _routine.entries.any((entry) {
      if (entry.practiceItemId == itemId) return true;
      return _entryContainsItem(entry.practiceItemId, itemId);
    });
  }

  List<PracticeItemV1> get routineItems {
    return _routine.entries
        .map((entry) => itemById(entry.practiceItemId))
        .toList(growable: false);
  }

  PracticeSessionLogV1? lastSessionForItem(String itemId) {
    for (final PracticeSessionLogV1 session in recentSessions) {
      if (_sessionContainsItem(session, itemId)) return session;
    }
    return null;
  }

  Duration totalTime({String? itemId, MaterialFamilyV1? family}) {
    Duration total = Duration.zero;

    for (final PracticeSessionLogV1 session in _sessions) {
      if (itemId != null && !_sessionContainsItem(session, itemId)) continue;
      if (family != null && session.family != family) continue;
      total += session.duration;
    }

    return total;
  }

  int sessionCount({String? itemId, MaterialFamilyV1? family}) {
    int total = 0;

    for (final PracticeSessionLogV1 session in _sessions) {
      if (itemId != null && !_sessionContainsItem(session, itemId)) continue;
      if (family != null && session.family != family) continue;
      total += 1;
    }

    return total;
  }

  bool usesKick(String itemId) =>
      _normalizedSticking(itemById(itemId)).contains('K');

  List<String> noteTokensFor(String itemId) {
    return _normalizedSticking(itemById(itemId)).split('');
  }

  List<PatternNoteMarkingV1> noteMarkingsFor(String itemId) {
    final PracticeItemV1 item = _sanitizedItem(itemById(itemId));
    final Set<int> accents = item.accentedNoteIndices.toSet();
    final Set<int> ghosts = item.ghostNoteIndices.toSet();

    return List<PatternNoteMarkingV1>.generate(item.noteCount, (index) {
      if (ghosts.contains(index)) return PatternNoteMarkingV1.ghost;
      if (accents.contains(index)) return PatternNoteMarkingV1.accent;
      return PatternNoteMarkingV1.normal;
    });
  }

  String markedPatternTextFor(String itemId) {
    final List<String> tokens = noteTokensFor(itemId);
    final List<PatternNoteMarkingV1> markings = noteMarkingsFor(itemId);
    return List<String>.generate(tokens.length, (index) {
      final String token = tokens[index];
      return switch (markings[index]) {
        PatternNoteMarkingV1.normal => token,
        PatternNoteMarkingV1.accent => '^$token',
        PatternNoteMarkingV1.ghost => '($token)',
      };
    }).join(' ');
  }

  List<DrumVoiceV1> noteVoicesFor(String itemId) {
    final PracticeItemV1 item = _sanitizedItem(itemById(itemId));
    return List<DrumVoiceV1>.unmodifiable(item.voiceAssignments);
  }

  bool hasKick(String itemId) => usesKick(itemId);

  bool handsOnly(String itemId) => !usesKick(itemId);

  bool startsWithRight(String itemId) => _firstNormalizedChar(itemId) == 'R';

  bool startsWithLeft(String itemId) => _firstNormalizedChar(itemId) == 'L';

  bool startsWithKick(String itemId) => _firstNormalizedChar(itemId) == 'K';

  bool endsWithKick(String itemId) => _lastNormalizedChar(itemId) == 'K';

  bool leadsWithWeakHand(String itemId) => _isWeakHandLead(itemById(itemId));

  bool hasDoubles(String itemId) {
    final String normalized = _normalizedSticking(itemById(itemId));
    if (normalized.length >= 3 && normalized.split('').toSet().length == 1) {
      return false;
    }
    for (int index = 0; index < normalized.length - 1; index++) {
      if (normalized[index] == normalized[index + 1]) return true;
    }
    return false;
  }

  String? mirrorItemId(String itemId) {
    final PracticeItemV1 item = itemById(itemId);
    if (!item.isTriad) return null;

    final String mirrored = _normalizedSticking(item).split('').map((ch) {
      return switch (ch) {
        'R' => 'L',
        'L' => 'R',
        _ => ch,
      };
    }).join();

    final PracticeItemV1? mirror = triadItemForCell(mirrored);
    return mirror?.id;
  }

  bool isUnseen(String itemId) => lastSessionForItem(itemId) == null;

  bool isRecent(String itemId) {
    final PracticeSessionLogV1? session = lastSessionForItem(itemId);
    if (session == null) return false;
    return DateTime.now().difference(session.endedAt) <=
        const Duration(days: 7);
  }

  bool isUnderPracticed(String itemId) {
    return totalTime(itemId: itemId) < const Duration(minutes: 12);
  }

  bool isCloseToToolbox(String itemId) {
    final CompetencyLevelV1 level = competencyFor(itemId);
    final bool strongCompetency =
        level == CompetencyLevelV1.comfortable ||
        level == CompetencyLevelV1.reliable;
    return strongCompetency &&
        totalTime(itemId: itemId) >= const Duration(minutes: 10);
  }

  bool needsAttention(String itemId) {
    final CompetencyLevelV1 level = competencyFor(itemId);
    final bool weakCompetency =
        level == CompetencyLevelV1.notStarted ||
        level == CompetencyLevelV1.learning;
    final bool stale = !isRecent(itemId);
    final bool lightTime =
        totalTime(itemId: itemId) < const Duration(minutes: 8);
    return weakCompetency && (stale || lightTime);
  }

  List<PracticeCombinationV1> get triadCombinations {
    final List<PracticeCombinationV1> combos = _combinations
        .where((combo) {
          return combo.itemIds.isNotEmpty &&
              combo.itemIds.every((itemId) => itemById(itemId).isTriad);
        })
        .toList(growable: false);
    combos.sort((a, b) => a.name.compareTo(b.name));
    return combos;
  }

  PracticeCombinationV1 combinationById(String id) {
    return _combinations.firstWhere((combo) => combo.id == id);
  }

  PracticeCombinationV1? combinationForItemIdsOrNull(List<String> itemIds) {
    for (final PracticeCombinationV1 combo in _combinations) {
      if (_sameOrderedItemIds(combo.itemIds, itemIds)) return combo;
    }
    return null;
  }

  String matrixLabelForCombination(String comboId) {
    final PracticeCombinationV1 combo = combinationById(comboId);
    return comboDisplayName(combo.itemIds);
  }

  String comboDisplayName(List<String> itemIds) {
    return itemIds.map((itemId) => itemById(itemId).name).join('-');
  }

  bool combinationContainsItem({
    required String comboId,
    required String itemId,
  }) {
    return combinationById(comboId).itemIds.contains(itemId);
  }

  bool _sessionContainsItem(PracticeSessionLogV1 session, String itemId) {
    for (final String sessionItemId in session.practiceItemIds) {
      if (sessionItemId == itemId) return true;
      if (_entryContainsItem(sessionItemId, itemId)) return true;
    }
    return false;
  }

  bool _entryContainsItem(String entryItemId, String itemId) {
    final PracticeItemV1? entryItem = itemByIdOrNull(entryItemId);
    if (entryItem == null || !entryItem.isCombo) return false;

    final PracticeCombinationV1? combo = _combinationByIdOrNull(entryItemId);
    if (combo == null) return false;
    return combo.itemIds.contains(itemId);
  }

  PracticeCombinationV1? _combinationByIdOrNull(String id) {
    for (final PracticeCombinationV1 combo in _combinations) {
      if (combo.id == id) return combo;
    }
    return null;
  }

  bool _sameOrderedItemIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  int weakHandNoteCount(String itemId) {
    final String weak = _profile.handedness == HandednessV1.right ? 'L' : 'R';
    return _normalizedSticking(
      itemById(itemId),
    ).split('').where((ch) => ch == weak).length;
  }

  String accentPatternLabelFor(String itemId) {
    final List<PatternNoteMarkingV1> markings = noteMarkingsFor(itemId);
    final Set<int> accented = <int>{
      for (int index = 0; index < markings.length; index++)
        if (markings[index] == PatternNoteMarkingV1.accent) index,
    };
    final PracticeItemV1 item = itemById(itemId);
    return List<String>.generate(
      item.noteCount,
      (index) => accented.contains(index) ? '^' : '·',
    ).join();
  }

  List<PracticeItemV1> itemsNeedingPractice(MaterialFamilyV1 family) {
    final List<PracticeItemV1> candidates = itemsByFamily(family);
    candidates.sort(_compareByNeed);
    return candidates;
  }

  void updateProfile(UserProfileV1 next) {
    _profile = next;
    notifyListeners();
  }

  void completeOnboarding(UserProfileV1 profile) {
    _profile = profile;
    _onboardingComplete = true;
    notifyListeners();
  }

  void clearAppData() {
    _profile = UserProfileV1.initial;
    _items = _basePracticeItems();
    _combinations = const <PracticeCombinationV1>[];
    _routine = const PracticeRoutineV1(
      id: 'main_routine',
      name: 'Working On',
      entries: <RoutineEntryV1>[],
    );
    _sessions = const <PracticeSessionLogV1>[];
    _competencyByItemId = <String, CompetencyRecordV1>{};
    _onboardingComplete = false;
    _resetVersion += 1;
    notifyListeners();
  }

  void updateCompetency(String itemId, CompetencyLevelV1 level) {
    _competencyByItemId[itemId] = CompetencyRecordV1(
      practiceItemId: itemId,
      level: level,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void setNoteMarking({
    required String itemId,
    required int noteIndex,
    required PatternNoteMarkingV1 marking,
  }) {
    final PracticeItemV1 item = itemById(itemId);
    if (noteIndex < 0 || noteIndex >= item.noteCount) return;

    final Set<int> accents = item.accentedNoteIndices.toSet();
    final Set<int> ghosts = item.ghostNoteIndices.toSet();

    accents.remove(noteIndex);
    ghosts.remove(noteIndex);

    switch (marking) {
      case PatternNoteMarkingV1.normal:
        break;
      case PatternNoteMarkingV1.accent:
        if (_tokenAt(item, noteIndex) != 'K') {
          accents.add(noteIndex);
        }
        break;
      case PatternNoteMarkingV1.ghost:
        ghosts.add(noteIndex);
        break;
    }

    _items = _items
        .map((entry) {
          if (entry.id != itemId) return entry;
          return _sanitizedItem(
            entry.copyWith(
              accentedNoteIndices: accents.toList()..sort(),
              ghostNoteIndices: ghosts.toList()..sort(),
            ),
          );
        })
        .toList(growable: false);
    notifyListeners();
  }

  void setNoteVoice({
    required String itemId,
    required int noteIndex,
    required DrumVoiceV1 voice,
  }) {
    final PracticeItemV1 item = itemById(itemId);
    if (noteIndex < 0 || noteIndex >= item.noteCount) return;

    final List<DrumVoiceV1> voices = List<DrumVoiceV1>.from(
      _sanitizedItem(item).voiceAssignments,
    );
    if (_tokenAt(item, noteIndex) == 'K') {
      voices[noteIndex] = DrumVoiceV1.kick;
    } else {
      voices[noteIndex] = voice == DrumVoiceV1.kick ? DrumVoiceV1.snare : voice;
    }

    _items = _items
        .map((entry) {
          if (entry.id != itemId) return entry;
          return _sanitizedItem(entry.copyWith(voiceAssignments: voices));
        })
        .toList(growable: false);
    notifyListeners();
  }

  PracticeItemV1 createCustomPattern({
    required String sticking,
    List<String> tags = const <String>[],
  }) {
    final String trimmedSticking = sticking.trim();
    final String canonicalName = _canonicalPatternName(trimmedSticking);
    final String signature = _patternSignature(trimmedSticking);

    for (final PracticeItemV1 item in _items) {
      if (item.isCustom && _patternSignature(item.sticking) == signature) {
        return item;
      }
    }

    final PracticeItemV1 item = PracticeItemV1(
      id: 'custom_${signature.toLowerCase()}',
      family: MaterialFamilyV1.custom,
      name: canonicalName,
      sticking: canonicalName,
      noteCount: _estimateNoteCount(trimmedSticking),
      accentedNoteIndices: _defaultAccentIndicesForSticking(trimmedSticking),
      ghostNoteIndices: const <int>[],
      voiceAssignments: _defaultVoiceAssignmentsForSticking(trimmedSticking),
      source: PracticeItemSourceV1.userDefined,
      tags: tags.where((tag) => tag.trim().isNotEmpty).toList(growable: false),
      saved: true,
    );

    _items = <PracticeItemV1>[..._items, _sanitizedItem(item)];
    notifyListeners();
    return item;
  }

  PracticeCombinationV1 createCombination({required List<String> itemIds}) {
    final String id = 'combo_${itemIds.join('_')}';
    final String comboName = comboDisplayName(itemIds);

    final PracticeCombinationV1? existing = combinationForItemIdsOrNull(
      itemIds,
    );
    if (existing != null) return existing;

    final PracticeCombinationV1 combo = PracticeCombinationV1(
      id: id,
      name: comboName,
      itemIds: List<String>.from(itemIds),
    );

    final int noteCount = itemIds.fold<int>(
      0,
      (sum, itemId) => sum + itemById(itemId).noteCount,
    );

    final List<int> accented = <int>[];
    final List<int> ghosted = <int>[];
    final List<DrumVoiceV1> voices = <DrumVoiceV1>[];
    int offset = 0;
    for (final String itemId in itemIds) {
      final PracticeItemV1 item = itemById(itemId);
      accented.addAll(item.accentedNoteIndices.map((index) => index + offset));
      ghosted.addAll(item.ghostNoteIndices.map((index) => index + offset));
      voices.addAll(_sanitizedItem(item).voiceAssignments);
      offset += item.noteCount;
    }

    final PracticeItemV1 comboItem = _sanitizedItem(
      PracticeItemV1(
        id: id,
        family: MaterialFamilyV1.combo,
        name: comboName,
        sticking: comboName,
        noteCount: noteCount,
        accentedNoteIndices: accented,
        ghostNoteIndices: ghosted,
        voiceAssignments: voices,
        source: PracticeItemSourceV1.userDefined,
        tags: <String>['combo'],
        saved: true,
      ),
    );

    _combinations = <PracticeCombinationV1>[combo, ..._combinations];
    _items = <PracticeItemV1>[..._items, comboItem];
    notifyListeners();
    return combo;
  }

  void toggleRoutineItem(String itemId) {
    final bool alreadyInRoutine = isDirectRoutineEntry(itemId);
    if (alreadyInRoutine) {
      _routine = _routine.copyWith(
        entries: _routine.entries
            .where((entry) => entry.practiceItemId != itemId)
            .toList(growable: false),
      );
    } else {
      _routine = _routine.copyWith(
        entries: <RoutineEntryV1>[
          ..._routine.entries,
          RoutineEntryV1(practiceItemId: itemId, addedAt: DateTime.now()),
        ],
      );
    }
    notifyListeners();
  }

  PracticeSessionSetupV1 buildSessionForItem(
    String itemId, {
    String? routineId,
  }) {
    final PracticeItemV1 item = itemById(itemId);
    return PracticeSessionSetupV1(
      practiceItemIds: <String>[itemId],
      family: item.family,
      practiceMode: PracticeModeV1.singleSurface,
      bpm: _profile.defaultBpm,
      timerPreset: _profile.defaultTimerPreset,
      clickEnabled: _profile.clickEnabledByDefault,
      routineId: routineId,
    );
  }

  PracticeSessionLogV1 completeSession(
    PracticeSessionSetupV1 setup,
    Duration duration, {
    ReflectionRatingV1? reflection,
  }) {
    final DateTime endedAt = DateTime.now();
    final PracticeSessionLogV1 session = PracticeSessionLogV1(
      id: 'session_${endedAt.microsecondsSinceEpoch}',
      startedAt: endedAt.subtract(duration),
      endedAt: endedAt,
      duration: duration,
      practiceItemIds: setup.practiceItemIds,
      family: setup.family,
      practiceMode: setup.practiceMode,
      bpm: setup.bpm,
      clickEnabled: setup.clickEnabled,
      routineId: setup.routineId,
      reflection: reflection,
    );

    _sessions = <PracticeSessionLogV1>[session, ..._sessions];
    notifyListeners();
    return session;
  }

  void updateSessionReflection(String sessionId, ReflectionRatingV1? rating) {
    _sessions = _sessions
        .map((session) {
          if (session.id != sessionId) return session;
          return session.copyWith(
            reflection: rating,
            clearReflection: rating == null,
          );
        })
        .toList(growable: false);
    notifyListeners();
  }

  String recentSummaryForItem(String itemId) {
    final PracticeSessionLogV1? session = lastSessionForItem(itemId);
    if (session == null) return 'No sessions yet';
    return '${formatShortDate(session.endedAt)} · ${formatDuration(session.duration)}';
  }

  int _compareByNeed(PracticeItemV1 a, PracticeItemV1 b) {
    final int competencyCompare = _competencyScore(
      competencyFor(a.id),
    ).compareTo(_competencyScore(competencyFor(b.id)));
    if (competencyCompare != 0) return competencyCompare;

    final int timeCompare = totalTime(
      itemId: a.id,
    ).compareTo(totalTime(itemId: b.id));
    if (timeCompare != 0) return timeCompare;

    final DateTime aDate =
        lastSessionForItem(a.id)?.endedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime bDate =
        lastSessionForItem(b.id)?.endedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return aDate.compareTo(bDate);
  }

  int _competencyScore(CompetencyLevelV1 level) {
    return switch (level) {
      CompetencyLevelV1.notStarted => 0,
      CompetencyLevelV1.learning => 1,
      CompetencyLevelV1.comfortable => 2,
      CompetencyLevelV1.reliable => 3,
      CompetencyLevelV1.musical => 4,
    };
  }

  bool _isWeakHandLead(PracticeItemV1 item) {
    final String weak = _profile.handedness == HandednessV1.right ? 'L' : 'R';
    return _firstHandChar(item.id) == weak;
  }

  String? _firstHandChar(String itemId) {
    final String normalized = _normalizedSticking(itemById(itemId));
    for (final String ch in normalized.split('')) {
      if (ch == 'R' || ch == 'L') return ch;
    }
    return null;
  }

  String? _firstNormalizedChar(String itemId) {
    final String normalized = _normalizedSticking(itemById(itemId));
    return normalized.isEmpty ? null : normalized[0];
  }

  String? _lastNormalizedChar(String itemId) {
    final String normalized = _normalizedSticking(itemById(itemId));
    return normalized.isEmpty ? null : normalized[normalized.length - 1];
  }

  String _normalizedSticking(PracticeItemV1 item) {
    return item.sticking.replaceAll(RegExp(r'[^RLK]'), '');
  }

  List<String> _normalizedTokensForItem(PracticeItemV1 item) {
    return _normalizedSticking(item).split('');
  }

  List<String> _normalizedTokensFromSticking(String sticking) {
    final String normalized = sticking.toUpperCase().replaceAll(
      RegExp(r'[^RLK]'),
      '',
    );
    return normalized.split('');
  }

  String? _tokenAt(PracticeItemV1 item, int index) {
    final List<String> tokens = _normalizedTokensForItem(item);
    if (index < 0 || index >= tokens.length) return null;
    return tokens[index];
  }

  PracticeItemV1 _sanitizedItem(PracticeItemV1 item) {
    final List<String> tokens = _normalizedTokensForItem(item);
    final List<int> accented =
        item.accentedNoteIndices
            .where(
              (index) =>
                  index >= 0 && index < tokens.length && tokens[index] != 'K',
            )
            .toSet()
            .toList()
          ..sort();
    final List<int> ghosted =
        item.ghostNoteIndices
            .where((index) => index >= 0 && index < tokens.length)
            .toSet()
            .toList()
          ..sort();
    final List<DrumVoiceV1> voices = List<DrumVoiceV1>.generate(tokens.length, (
      index,
    ) {
      final DrumVoiceV1 fallback = _defaultVoiceForToken(tokens[index]);
      if (index >= item.voiceAssignments.length) return fallback;
      final DrumVoiceV1 voice = item.voiceAssignments[index];
      if (tokens[index] == 'K') return DrumVoiceV1.kick;
      return voice == DrumVoiceV1.kick ? fallback : voice;
    });

    if (listEquals(accented, item.accentedNoteIndices) &&
        listEquals(ghosted, item.ghostNoteIndices) &&
        listEquals(voices, item.voiceAssignments)) {
      return item;
    }

    return item.copyWith(
      accentedNoteIndices: accented,
      ghostNoteIndices: ghosted,
      voiceAssignments: voices,
    );
  }

  String _patternSignature(String sticking) {
    return sticking.toUpperCase().replaceAll(RegExp(r'[^RLK]'), '');
  }

  String _canonicalPatternName(String sticking) {
    final String signature = _patternSignature(sticking);
    if (signature.isEmpty) return sticking.trim().toUpperCase();
    return signature.split('').join(' ');
  }

  int _estimateNoteCount(String sticking) {
    final List<String> tokens = sticking
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);
    return tokens.isEmpty ? sticking.length : tokens.length;
  }

  List<int> _defaultAccentIndicesForSticking(String sticking) {
    final List<String> tokens = _normalizedTokensFromSticking(sticking);
    if (tokens.isEmpty) return const <int>[];

    final List<int> handIndices = <int>[
      for (int index = 0; index < tokens.length; index++)
        if (tokens[index] != 'K') index,
    ];
    if (handIndices.isEmpty) return const <int>[];
    if (handIndices.length >= 3) {
      return <int>[handIndices.first, handIndices[2]];
    }
    return <int>[handIndices.first];
  }

  List<DrumVoiceV1> _defaultVoiceAssignmentsForSticking(String sticking) {
    return _normalizedTokensFromSticking(
      sticking,
    ).map(_defaultVoiceForToken).toList(growable: false);
  }

  DrumVoiceV1 _defaultVoiceForToken(String token) {
    return token == 'K' ? DrumVoiceV1.kick : DrumVoiceV1.snare;
  }

  String _triadItemId(String cellId) => 'triad_${cellId.toLowerCase()}';

  List<String> _tagsForTriadCell(TriadMatrixCell cell) {
    final List<String> tags = <String>['matrix'];
    if (cell.handsOnly) {
      tags.add('hands');
    } else {
      tags.add('kit');
    }
    if (cell.hasHandDouble) tags.add('double');
    if (cell.hasKickDouble) tags.add('kick-double');
    if (cell.id.startsWith('R')) tags.add('lead-right');
    if (cell.id.startsWith('L')) tags.add('lead-left');
    if (cell.id.startsWith('K')) tags.add('lead-kick');
    return tags;
  }

  List<int> _accentIndicesForTriadCell(TriadMatrixCell cell) {
    return _defaultAccentIndicesForSticking(cell.id);
  }

  void _seed() {
    _profile = UserProfileV1.initial;
    _items = _basePracticeItems();
    _combinations = const <PracticeCombinationV1>[];
    _routine = const PracticeRoutineV1(
      id: 'main_routine',
      name: 'Working On',
      entries: <RoutineEntryV1>[],
    );
    _sessions = const <PracticeSessionLogV1>[];
    _competencyByItemId = <String, CompetencyRecordV1>{};
  }

  List<PracticeItemV1> _basePracticeItems() {
    final List<PracticeItemV1> triadItems = triadMatrixAll()
        .map(
          (cell) => PracticeItemV1(
            id: _triadItemId(cell.id),
            family: MaterialFamilyV1.triad,
            name: cell.id,
            sticking: cell.id,
            noteCount: 3,
            accentedNoteIndices: _accentIndicesForTriadCell(cell),
            ghostNoteIndices: const <int>[],
            voiceAssignments: _defaultVoiceAssignmentsForSticking(cell.id),
            source: PracticeItemSourceV1.builtIn,
            tags: _tagsForTriadCell(cell),
            saved: true,
          ),
        )
        .toList(growable: false);

    return <PracticeItemV1>[
      ...triadItems,
      const PracticeItemV1(
        id: 'five_rlrlk',
        family: MaterialFamilyV1.fiveNote,
        name: 'RLRLK',
        sticking: 'RLRLK',
        noteCount: 5,
        accentedNoteIndices: <int>[0],
        ghostNoteIndices: <int>[],
        voiceAssignments: <DrumVoiceV1>[
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.kick,
        ],
        source: PracticeItemSourceV1.builtIn,
        tags: <String>['5s'],
        saved: true,
      ),
      const PracticeItemV1(
        id: 'five_rllrl',
        family: MaterialFamilyV1.fiveNote,
        name: 'RLLRL',
        sticking: 'RLLRL',
        noteCount: 5,
        accentedNoteIndices: <int>[0, 3],
        ghostNoteIndices: <int>[1],
        voiceAssignments: <DrumVoiceV1>[
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
        ],
        source: PracticeItemSourceV1.builtIn,
        tags: <String>['5s'],
        saved: true,
      ),
    ];
  }
}
