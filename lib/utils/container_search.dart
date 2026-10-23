/// Normalises a container search term so separators don't have to be typed
/// exactly: whitespace and dash variants (en/em dash, minus sign - e.g. a
/// phone keyboard's auto-substitution) become a plain "-", and a bare
/// letters-then-digits term gets the hyphen inserted ("G5" -> "g-5"). The
/// result is lowercased and meant for a literal `contains` match on the
/// lowercased id - mirrored by `normalizeSearch` in
/// `backend/src/validation.ts`, so the home list and `GET /containers`
/// agree.
///
/// Only the search term is rewritten, never the ids, so distinct ids stay
/// distinct: "G25" finds "G-25" but never "G2-5".
String normalizeContainerSearch(String search) {
  final cleaned = search
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-‐-―−]+'), '-');
  final match = RegExp(r'^([a-z]+)([0-9]+)$').firstMatch(cleaned);
  return match == null ? cleaned : '${match[1]}-${match[2]}';
}
