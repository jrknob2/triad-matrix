// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_state_store.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAppStateRecordCollection on Isar {
  IsarCollection<AppStateRecord> get appStateRecords => this.collection();
}

const AppStateRecordSchema = CollectionSchema(
  name: r'AppStateRecord',
  id: 4728061756950040693,
  properties: {
    r'combinationsJson': PropertySchema(
      id: 0,
      name: r'combinationsJson',
      type: IsarType.string,
    ),
    r'competencyJson': PropertySchema(
      id: 1,
      name: r'competencyJson',
      type: IsarType.string,
    ),
    r'itemsJson': PropertySchema(
      id: 2,
      name: r'itemsJson',
      type: IsarType.string,
    ),
    r'onboardingComplete': PropertySchema(
      id: 3,
      name: r'onboardingComplete',
      type: IsarType.bool,
    ),
    r'profileJson': PropertySchema(
      id: 4,
      name: r'profileJson',
      type: IsarType.string,
    ),
    r'routineJson': PropertySchema(
      id: 5,
      name: r'routineJson',
      type: IsarType.string,
    ),
    r'schemaVersion': PropertySchema(
      id: 6,
      name: r'schemaVersion',
      type: IsarType.long,
    ),
    r'sessionsJson': PropertySchema(
      id: 7,
      name: r'sessionsJson',
      type: IsarType.string,
    )
  },
  estimateSize: _appStateRecordEstimateSize,
  serialize: _appStateRecordSerialize,
  deserialize: _appStateRecordDeserialize,
  deserializeProp: _appStateRecordDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _appStateRecordGetId,
  getLinks: _appStateRecordGetLinks,
  attach: _appStateRecordAttach,
  version: '3.1.0+1',
);

int _appStateRecordEstimateSize(
  AppStateRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.combinationsJson.length * 3;
  bytesCount += 3 + object.competencyJson.length * 3;
  bytesCount += 3 + object.itemsJson.length * 3;
  bytesCount += 3 + object.profileJson.length * 3;
  bytesCount += 3 + object.routineJson.length * 3;
  bytesCount += 3 + object.sessionsJson.length * 3;
  return bytesCount;
}

void _appStateRecordSerialize(
  AppStateRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.combinationsJson);
  writer.writeString(offsets[1], object.competencyJson);
  writer.writeString(offsets[2], object.itemsJson);
  writer.writeBool(offsets[3], object.onboardingComplete);
  writer.writeString(offsets[4], object.profileJson);
  writer.writeString(offsets[5], object.routineJson);
  writer.writeLong(offsets[6], object.schemaVersion);
  writer.writeString(offsets[7], object.sessionsJson);
}

AppStateRecord _appStateRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppStateRecord();
  object.combinationsJson = reader.readString(offsets[0]);
  object.competencyJson = reader.readString(offsets[1]);
  object.id = id;
  object.itemsJson = reader.readString(offsets[2]);
  object.onboardingComplete = reader.readBool(offsets[3]);
  object.profileJson = reader.readString(offsets[4]);
  object.routineJson = reader.readString(offsets[5]);
  object.schemaVersion = reader.readLong(offsets[6]);
  object.sessionsJson = reader.readString(offsets[7]);
  return object;
}

P _appStateRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _appStateRecordGetId(AppStateRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appStateRecordGetLinks(AppStateRecord object) {
  return [];
}

void _appStateRecordAttach(
    IsarCollection<dynamic> col, Id id, AppStateRecord object) {
  object.id = id;
}

extension AppStateRecordQueryWhereSort
    on QueryBuilder<AppStateRecord, AppStateRecord, QWhere> {
  QueryBuilder<AppStateRecord, AppStateRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppStateRecordQueryWhere
    on QueryBuilder<AppStateRecord, AppStateRecord, QWhereClause> {
  QueryBuilder<AppStateRecord, AppStateRecord, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AppStateRecordQueryFilter
    on QueryBuilder<AppStateRecord, AppStateRecord, QFilterCondition> {
  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      combinationsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'combinationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      combinationsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'combinationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      combinationsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'combinationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      combinationsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'combinationsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      combinationsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'combinationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      combinationsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'combinationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      combinationsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'combinationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      combinationsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'combinationsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      combinationsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'combinationsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      combinationsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'combinationsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      competencyJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'competencyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      competencyJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'competencyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      competencyJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'competencyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      competencyJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'competencyJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      competencyJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'competencyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      competencyJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'competencyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      competencyJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'competencyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      competencyJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'competencyJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      competencyJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'competencyJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      competencyJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'competencyJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      itemsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'itemsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      itemsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'itemsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      itemsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'itemsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      itemsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'itemsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      itemsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'itemsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      itemsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'itemsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      itemsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'itemsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      itemsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'itemsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      itemsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'itemsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      itemsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'itemsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      onboardingCompleteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'onboardingComplete',
        value: value,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      profileJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'profileJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      profileJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'profileJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      profileJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'profileJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      profileJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'profileJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      profileJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'profileJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      profileJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'profileJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      profileJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'profileJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      profileJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'profileJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      profileJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'profileJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      profileJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'profileJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      routineJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routineJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      routineJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'routineJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      routineJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'routineJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      routineJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'routineJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      routineJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'routineJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      routineJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'routineJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      routineJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'routineJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      routineJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'routineJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      routineJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routineJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      routineJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'routineJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      schemaVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      schemaVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      schemaVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      schemaVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'schemaVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      sessionsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      sessionsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sessionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      sessionsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sessionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      sessionsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sessionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      sessionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sessionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      sessionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sessionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      sessionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sessionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      sessionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sessionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      sessionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterFilterCondition>
      sessionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sessionsJson',
        value: '',
      ));
    });
  }
}

extension AppStateRecordQueryObject
    on QueryBuilder<AppStateRecord, AppStateRecord, QFilterCondition> {}

extension AppStateRecordQueryLinks
    on QueryBuilder<AppStateRecord, AppStateRecord, QFilterCondition> {}

extension AppStateRecordQuerySortBy
    on QueryBuilder<AppStateRecord, AppStateRecord, QSortBy> {
  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortByCombinationsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'combinationsJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortByCombinationsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'combinationsJson', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortByCompetencyJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'competencyJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortByCompetencyJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'competencyJson', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy> sortByItemsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemsJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortByItemsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemsJson', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortByOnboardingComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortByOnboardingCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortByProfileJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profileJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortByProfileJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profileJson', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortByRoutineJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routineJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortByRoutineJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routineJson', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortBySessionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionsJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      sortBySessionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionsJson', Sort.desc);
    });
  }
}

extension AppStateRecordQuerySortThenBy
    on QueryBuilder<AppStateRecord, AppStateRecord, QSortThenBy> {
  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenByCombinationsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'combinationsJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenByCombinationsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'combinationsJson', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenByCompetencyJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'competencyJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenByCompetencyJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'competencyJson', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy> thenByItemsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemsJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenByItemsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemsJson', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenByOnboardingComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenByOnboardingCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenByProfileJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profileJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenByProfileJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profileJson', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenByRoutineJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routineJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenByRoutineJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routineJson', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenBySessionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionsJson', Sort.asc);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QAfterSortBy>
      thenBySessionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionsJson', Sort.desc);
    });
  }
}

extension AppStateRecordQueryWhereDistinct
    on QueryBuilder<AppStateRecord, AppStateRecord, QDistinct> {
  QueryBuilder<AppStateRecord, AppStateRecord, QDistinct>
      distinctByCombinationsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'combinationsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QDistinct>
      distinctByCompetencyJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'competencyJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QDistinct> distinctByItemsJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QDistinct>
      distinctByOnboardingComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'onboardingComplete');
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QDistinct> distinctByProfileJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'profileJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QDistinct> distinctByRoutineJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'routineJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QDistinct>
      distinctBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'schemaVersion');
    });
  }

  QueryBuilder<AppStateRecord, AppStateRecord, QDistinct>
      distinctBySessionsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionsJson', caseSensitive: caseSensitive);
    });
  }
}

extension AppStateRecordQueryProperty
    on QueryBuilder<AppStateRecord, AppStateRecord, QQueryProperty> {
  QueryBuilder<AppStateRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppStateRecord, String, QQueryOperations>
      combinationsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'combinationsJson');
    });
  }

  QueryBuilder<AppStateRecord, String, QQueryOperations>
      competencyJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'competencyJson');
    });
  }

  QueryBuilder<AppStateRecord, String, QQueryOperations> itemsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemsJson');
    });
  }

  QueryBuilder<AppStateRecord, bool, QQueryOperations>
      onboardingCompleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'onboardingComplete');
    });
  }

  QueryBuilder<AppStateRecord, String, QQueryOperations> profileJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'profileJson');
    });
  }

  QueryBuilder<AppStateRecord, String, QQueryOperations> routineJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'routineJson');
    });
  }

  QueryBuilder<AppStateRecord, int, QQueryOperations> schemaVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'schemaVersion');
    });
  }

  QueryBuilder<AppStateRecord, String, QQueryOperations>
      sessionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionsJson');
    });
  }
}
