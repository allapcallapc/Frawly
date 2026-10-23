/// The forms a container search term is matched under, so separators
/// don't have to be typed exactly. Whitespace and dash variants (en/em
/// dash, minus sign - e.g. a phone keyboard's auto-substitution) become a
/// plain "-", and a bare letters-then-digits term also yields a form with
/// the hyphen inserted ("G5" -> "g5" and "g-5"). Lowercased; an id matches
/// when its lowercased form contains any of them. Mirrored by
/// `searchForms` in `backend/src/validation.ts`, so the home list and
/// `GET /containers` agree.
///
/// Only the search term is rewritten, never the ids, so distinct ids stay
/// distinct: "G25" finds "G-25" but never "G2-5", while "G2" still finds
/// the "G2" prefix's "G2-5". Empty for a blank term.
List<String> containerSearchForms(String search) {
  final cleaned = search
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-‐-―−]+'), '-');
  if (cleaned.isEmpty) return const [];
  final match = RegExp(r'^([a-z]+)([0-9]+)$').firstMatch(cleaned);
  return match == null ? [cleaned] : [cleaned, '${match[1]}-${match[2]}'];
}
