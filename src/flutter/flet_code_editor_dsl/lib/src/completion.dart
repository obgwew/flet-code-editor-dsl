/// Pure completion helpers shared by the editor and unit tests.
///
/// The trigger is deliberately separate from the command word. With a `$`
/// trigger, the cursor must be after at least one identifier character in a
/// word immediately preceded by `$`; a bare `$` never opens the list.
String completionPrefixAt(String line, int offset) {
  if (offset < 0 || offset > line.length) return '';
  return RegExp(r'[A-Za-z_][A-Za-z0-9_]*$')
          .firstMatch(line.substring(0, offset))
          ?.group(0) ??
      '';
}

bool completionHasTriggerAt({
  required String line,
  required int offset,
  required String prefix,
  required String trigger,
}) {
  if (trigger.isEmpty || prefix.isEmpty || offset < 0 || offset > line.length) {
    return false;
  }
  final start = offset - prefix.length;
  return start >= trigger.length &&
      line.substring(start - trigger.length, start) == trigger;
}

List<String> completionCandidates({
  required String prefix,
  required Iterable<String> words,
  required String trigger,
  Map<String, int> recent = const {},
  int? limit,
}) {
  if (prefix.isEmpty || (limit != null && limit <= 0)) return const [];
  final triggered = trigger.isNotEmpty;
  final normalized = <String>{};
  for (final raw in words) {
    final word = triggered && raw.startsWith(trigger)
        ? raw.substring(trigger.length)
        : raw;
    if (word.isNotEmpty &&
        word.toLowerCase() != prefix.toLowerCase() &&
        word.toLowerCase().startsWith(prefix.toLowerCase())) {
      normalized.add(word);
    }
  }
  final matches = normalized.toList()
    ..sort((a, b) {
      final recentOrder = (recent[b] ?? 0).compareTo(recent[a] ?? 0);
      return recentOrder != 0 ? recentOrder : a.compareTo(b);
    });
  final Iterable<String> results =
      limit == null ? matches : matches.take(limit);
  return triggered
      ? [for (final word in results) '$trigger$word']
      : results.toList();
}

/// The typed trigger remains in the source; replace only the command name.
String completionInsertion({
  required String suggestion,
  required String trigger,
  required bool hasTrigger,
}) {
  return hasTrigger && suggestion.startsWith(trigger)
      ? suggestion.substring(trigger.length)
      : suggestion;
}
