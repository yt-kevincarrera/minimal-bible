/// Reparación del texto de los versículos.
///
/// En el texto de origen la poesía (Salmos, Job, Proverbios…) perdió los
/// saltos de línea: cada línea poética quedó pegada a la anterior sin espacio
/// ("mis palabras,Y mis mandamientos", "la vidaY ver"). Como en la RV1960 cada
/// línea poética empieza con mayúscula, al leerse como prosa aparecen
/// mayúsculas tras coma. Aquí se reinserta el espacio y, cuando la unión es a
/// mitad de frase, se pasa a minúscula la palabra salvo que sea un nombre
/// propio.
library;

final _word = RegExp(r'\p{L}+', unicode: true);

/// Palabra con mayúscula precedida de "minúscula/coma/punto y coma + espacio":
/// una mayúscula auténtica a mitad de frase (nombre propio).
final _midSentenceCap = RegExp(r'(?<=[\p{Ll},;] )\p{Lu}\p{L}*', unicode: true);

/// Uniones sin espacio: signo seguido de letra ("palabras,Y") o minúscula
/// seguida de mayúscula ("vidaY"). Grupo 1: lo que precede; grupo 2: signo
/// de apertura opcional; grupo 3: la palabra siguiente.
final _join = RegExp(
  r'([,;.:!?»)]|\p{Ll}(?=[¿¡«(]?\p{Lu}))([¿¡«(]?)(\p{L}+)',
  unicode: true,
);

final _spaces = RegExp(r'\s+');

/// Nombres que también son verbos comunes y que, en las uniones, aparecen
/// como verbo ("Dan voces de júbilo", Sal 65:13; "Atad víctimas", Sal 118:27).
const _namesThatAreVerbs = {'Dan', 'Atad'};

/// Nombres propios del [corpus]: palabras que aparecen con mayúscula a mitad
/// de frase al menos tantas veces como en minúscula ("Jehová", "Dios",
/// "Señor"). Se devuelven con su mayúscula inicial.
Set<String> properNounsFrom(Iterable<String> corpus) {
  final lower = <String, int>{};
  final midCap = <String, int>{};
  for (final text in corpus) {
    for (final m in _word.allMatches(text)) {
      final w = m[0]!;
      if (w[0] != w[0].toUpperCase()) lower[w] = (lower[w] ?? 0) + 1;
    }
    for (final m in _midSentenceCap.allMatches(text)) {
      final w = m[0]!;
      midCap[w] = (midCap[w] ?? 0) + 1;
    }
  }
  return {
    for (final e in midCap.entries)
      if (e.value >= (lower[e.key.toLowerCase()] ?? 0) &&
          !_namesThatAreVerbs.contains(e.key))
        e.key,
  };
}

/// Devuelve [raw] sin espacios sobrantes y con las líneas poéticas unidas
/// separadas por un espacio. Tras coma, punto y coma o sin puntuación (la
/// frase sigue) pasa a minúscula la palabra salvo que esté en [properNouns];
/// tras punto, dos puntos, ? o ! (frase o cita nueva) conserva la mayúscula.
String normalizeVerseText(String raw, Set<String> properNouns) {
  final text = raw.trim().replaceAll(_spaces, ' ');
  return text.replaceAllMapped(_join, (m) {
    final before = m[1]!;
    final opener = m[2]!;
    var word = m[3]!;
    final first = word[0];
    final isUpper = first != first.toLowerCase();
    final afterLetter = before != before.toUpperCase();
    final continues = afterLetter || before == ',' || before == ';';
    if (continues && isUpper && !properNouns.contains(word)) {
      word = first.toLowerCase() + word.substring(1);
    }
    return '$before $opener$word';
  });
}
