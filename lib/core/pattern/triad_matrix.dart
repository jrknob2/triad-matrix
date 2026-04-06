// lib/core/pattern/triad_matrix.dart
//
// Drumcabulary — Triad Matrix (v1)
//
// Purpose:
// - Canonical, baked-in triad matrix data (R/L/K).
// - Stable, deterministic traversal order for Previous/Next.
// - Minimal helpers to index, wrap, and access cells.
// - Lightweight semantic helpers for UI/Controller rules (pad vs kit, accents, etc.).
//
// Notes:
// - Keep this file pure data + tiny helpers.
// - Validation runs once in debug via assert() to catch mistakes early.

import 'pattern_engine.dart';

/* ------------------------------- Public Types ------------------------------ */

/// One triad cell in the matrix (e.g. "LRK").
///
/// `limbs` is derived directly from the id.
class TriadMatrixCell {
  final String id; // exactly 3 chars, each in {R,L,K}
  final List<Limb> limbs; // length 3

  const TriadMatrixCell({
    required this.id,
    required this.limbs,
  });

  /// True if the triad contains kick at least once.
  bool get usesKick => id.contains('K');

  /// True if the triad is hands-only (no kick).
  bool get handsOnly => !usesKick;

  /// True if the triad contains a consecutive double stroke with the hands
  /// somewhere in the cell (RR or LL).
  ///
  /// Examples:
  /// - "RRL" => true (RR)
  /// - "LRR" => true (RR)
  /// - "RLR" => false
  bool get hasHandDouble =>
      id.contains('RR') || id.contains('LL');

  /// True if the triad contains a consecutive kick double ("KK").
  bool get hasKickDouble => id.contains('KK');

  /// Convenience: whether accents should be allowed on this triad under the
  /// simplified v1 rule you stated:
  /// - no accents on kicks
  /// - no accents on double-hand cells (RR / LL anywhere)
  ///
  /// (We keep this here as a *data* helper; rendering still decides how/where.)
  bool get accentsAllowedV1 => !usesKick && !hasHandDouble;
}

/* ----------------------------- Matrix Ordering ----------------------------- */
/*
Matrix (as provided):

      R     L     K
   +-----+-----+-----+
RR | RRR | LRR | KRR |
LL | RLL | LLL | KLL |
RL | RRL | LRL | KRL |
LR | RLR | LLR | KLR |
KK | RKK | LKK | KKK |
RK | RRK | LRK | KRK |
LK | RLK | LLK | KLK |
KR | RKR | LKR | KKR |
KL | RKL | LKL | KKL |
   +-----+-----+-----+

Traversal order:
- Row-major by the row headers in the exact order above.
- Within a row, column-major by (R, L, K) — but note the cell id format is:
  [colLimb][rowPair] => e.g. row "RR" column "L" => "LRR".
*/

const List<String> _rowPairs = <String>[
  'RR',
  'LL',
  'RL',
  'LR',
  'KK',
  'RK',
  'LK',
  'KR',
  'KL',
];

const List<String> _colLimbs = <String>['R', 'L', 'K'];

/* ------------------------------- Data Build -------------------------------- */

List<TriadMatrixCell> _buildCells() {
  final List<TriadMatrixCell> out = <TriadMatrixCell>[];

  for (final String row in _rowPairs) {
    for (final String col in _colLimbs) {
      final String id = '$col$row'; // e.g. L + RR => LRR
      out.add(
        TriadMatrixCell(
          id: id,
          limbs: _idToLimbs(id),
        ),
      );
    }
  }

  return out;
}

final List<TriadMatrixCell> _cells = _buildCells();
final Map<String, int> _indexById = _buildIndexById(_cells);

Map<String, int> _buildIndexById(List<TriadMatrixCell> cells) {
  final Map<String, int> out = <String, int>{};
  for (int i = 0; i < cells.length; i++) {
    out[cells[i].id] = i;
  }
  return out;
}

/* ------------------------------ Public Helpers ----------------------------- */

int triadMatrixLength() {
  assert(_validateMatrixOnce());
  return _cells.length;
}

TriadMatrixCell triadMatrixCellAt(int index) {
  assert(_validateMatrixOnce());

  final int len = _cells.length;
  if (len == 0) {
    throw StateError('[triad_matrix] matrix is empty');
  }

  final int i = _wrapIndex(index, len);
  return _cells[i];
}

int triadMatrixNextIndex(int index) {
  assert(_validateMatrixOnce());
  return _wrapIndex(index + 1, _cells.length);
}

int triadMatrixPrevIndex(int index) {
  assert(_validateMatrixOnce());
  return _wrapIndex(index - 1, _cells.length);
}

/// Optional nice label for UI like "5 / 27".
String triadMatrixPositionLabel(int index) {
  assert(_validateMatrixOnce());
  final int len = _cells.length;
  if (len == 0) return '0 / 0';
  final int i = _wrapIndex(index, len);
  return '${i + 1} / $len';
}

/// Returns an unmodifiable view of the full matrix in deterministic order.
List<TriadMatrixCell> triadMatrixAll() {
  assert(_validateMatrixOnce());
  return List<TriadMatrixCell>.unmodifiable(_cells);
}

/// Lookup index by cell id; returns -1 if not found.
int triadMatrixIndexOfId(String id) {
  assert(_validateMatrixOnce());
  final String key = id.trim().toUpperCase();
  return _indexById[key] ?? -1;
}

/// Lookup cell by id; returns null if not found.
TriadMatrixCell? triadMatrixCellById(String id) {
  assert(_validateMatrixOnce());
  final int idx = triadMatrixIndexOfId(id);
  if (idx < 0) return null;
  return _cells[idx];
}

/// Convenience: hands-only cells (no kick).
List<TriadMatrixCell> triadMatrixHandsOnly() {
  assert(_validateMatrixOnce());
  final List<TriadMatrixCell> out = <TriadMatrixCell>[];
  for (final TriadMatrixCell c in _cells) {
    if (c.handsOnly) out.add(c);
  }
  return List<TriadMatrixCell>.unmodifiable(out);
}

/// Convenience: cells that include kick.
List<TriadMatrixCell> triadMatrixWithKick() {
  assert(_validateMatrixOnce());
  final List<TriadMatrixCell> out = <TriadMatrixCell>[];
  for (final TriadMatrixCell c in _cells) {
    if (c.usesKick) out.add(c);
  }
  return List<TriadMatrixCell>.unmodifiable(out);
}

/// Rules helpers (pure):
/// - Pad: kick triads are invalid
/// - Kit: anything goes
bool triadMatrixIsValidForPad(TriadMatrixCell cell) => cell.handsOnly;
bool triadMatrixIsValidForKit(TriadMatrixCell cell) => true;

/* ----------------------------- Internal Helpers ---------------------------- */

int _wrapIndex(int index, int len) {
  if (len <= 0) return 0;
  final int m = index % len;
  return m < 0 ? m + len : m;
}

List<Limb> _idToLimbs(String id) {
  if (id.length != 3) {
    throw ArgumentError.value(id, 'id', 'Triad id must be 3 characters');
  }
  return <Limb>[
    _charToLimb(id[0]),
    _charToLimb(id[1]),
    _charToLimb(id[2]),
  ];
}

Limb _charToLimb(String ch) {
  return switch (ch) {
    'R' => Limb.r,
    'L' => Limb.l,
    'K' => Limb.k,
    _ => throw ArgumentError.value(ch, 'ch', 'Expected R, L, or K'),
  };
}

/* ------------------------------ Debug Validation --------------------------- */

bool _validated = false;

/// Debug-only validation; returns true so it can be used in assert().
bool _validateMatrixOnce() {
  if (_validated) return true;

  // The function body is cheap; still, keep it deterministic.
  final int len = _cells.length;

  // 9 rows * 3 cols = 27 cells
  if (len != _rowPairs.length * _colLimbs.length) {
    throw StateError(
      '[triad_matrix] expected ${_rowPairs.length * _colLimbs.length} cells, got $len',
    );
  }

  // Unique ids, all valid chars, and each id length is 3.
  final Set<String> ids = <String>{};
  for (final TriadMatrixCell c in _cells) {
    if (c.id.length != 3) {
      throw StateError('[triad_matrix] bad id length: "${c.id}"');
    }
    for (int i = 0; i < 3; i++) {
      final String ch = c.id[i];
      if (ch != 'R' && ch != 'L' && ch != 'K') {
        throw StateError('[triad_matrix] invalid char "$ch" in id "${c.id}"');
      }
    }
    if (!ids.add(c.id)) {
      throw StateError('[triad_matrix] duplicate cell id "${c.id}"');
    }
    if (c.limbs.length != 3) {
      throw StateError('[triad_matrix] limbs length != 3 for "${c.id}"');
    }
  }

  // Index map must match.
  if (_indexById.length != _cells.length) {
    throw StateError('[triad_matrix] id->index map size mismatch');
  }
  for (int i = 0; i < _cells.length; i++) {
    final String id = _cells[i].id;
    final int mapped = _indexById[id] ?? -1;
    if (mapped != i) {
      throw StateError('[triad_matrix] id->index map mismatch for "$id"');
    }
  }

  // Ensure the traversal order includes the exact user-provided set.
  const Set<String> required = <String>{
    'RRR','LRR','KRR',
    'RLL','LLL','KLL',
    'RRL','LRL','KRL',
    'RLR','LLR','KLR',
    'RKK','LKK','KKK',
    'RRK','LRK','KRK',
    'RLK','LLK','KLK',
    'RKR','LKR','KKR',
    'RKL','LKL','KKL',
  };

  if (!ids.containsAll(required) || ids.length != required.length) {
    throw StateError('[triad_matrix] matrix ids do not match required set');
  }

  _validated = true;
  return true;
}
