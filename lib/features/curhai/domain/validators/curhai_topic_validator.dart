import 'package:kitatemani/features/curhai/data/repositories/curhai_repository_impl.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_message.dart';

/// Rejection categories for requests that fall outside CurhAI's scope.
enum CurhaiTopicRejectionCategory {
  mathFormula,
  academicHomework,
  codingTech,
  generalOffTopic,
  promptInjection,
}

/// Result of validating whether a CurhAI user message stays within scope.
class CurhaiTopicValidationResult {
  const CurhaiTopicValidationResult.allowed()
      : isAllowed = true,
        category = null,
        refusalMessage = null;

  const CurhaiTopicValidationResult.rejected({
    required CurhaiTopicRejectionCategory this.category,
    required String this.refusalMessage,
  }) : isAllowed = false;

  final bool isAllowed;
  final CurhaiTopicRejectionCategory? category;
  final String? refusalMessage;
}

/// Returns a warm, empathetic Indonesian refusal tailored to [category].
String curhaiRefusalMessageForCategory(CurhaiTopicRejectionCategory category) {
  switch (category) {
    case CurhaiTopicRejectionCategory.mathFormula:
      return 'Maaf ya, aku belum bisa membantu memberikan rumus, hitungan matematika, atau menyelesaikan soal pelajaran.\n\nCurhAI khusus menemani kamu bercerita soal perundungan (*bullying*), perasaanmu, atau cerita personal seperti hobi dan keseharianmu. Kalau pelajaran itu bikin kamu tertekan atau ada masalah dengan teman di sekolah, yuk ceritakan ke aku.';
    case CurhaiTopicRejectionCategory.academicHomework:
      return 'Maaf ya, CurhAI tidak bisa mengerjakan PR, tugas sekolah, esai, atau menjelaskan materi pelajaran seperti asisten belajar.\n\nRuang ini khusus untuk mendengarkan ceritamu tentang perundungan, rasa cemas, maupun cerita personal tentang diri dan hobimu. Kalau ada hal di sekolah yang bikin kamu berat atau tidak nyaman, aku siap mendengarkan.';
    case CurhaiTopicRejectionCategory.codingTech:
      return 'Maaf ya, aku tidak bisa membantu membuatkan kode program, *debugging*, atau menjawab pertanyaan teknis pemrograman.\n\nCurhAI hadir khusus untuk mendukungmu soal *bullying*, perasaan, dan cerita personal seperti hobi atau keseharianmu. Kalau kamu mau cerita tentang pengalamanmu atau hal yang lagi kamu rasakan, aku ada di sini.';
    case CurhaiTopicRejectionCategory.promptInjection:
      return 'Aku tetap di sini sebagai CurhAI, teman curhat khusus untuk membicarakan pengalaman perundungan, perasaanmu, dan cerita personal tentang dirimu seperti hobi atau aktivitasmu.\n\nMaaf, aku tidak bisa mengubah peran atau menjawab permintaan di luar topik tersebut. Ada hal yang sedang ingin kamu ceritakan hari ini?';
    case CurhaiTopicRejectionCategory.generalOffTopic:
      return 'Maaf ya, permintaan itu berada di luar fokus CurhAI.\n\nAku dirancang khusus untuk menemani kamu seputar pengalaman *bullying*, perasaan emosional, serta cerita personal tentang dirimu—mulai dari hobi, kegiatan sehari-hari, sampai hubungan dengan teman. Mau cerita apa hari ini?';
  }
}

const List<String> _urgentSafetyPhrases = <String>[
  'bunuh',
  'menyakiti diri',
  'melukai diri',
  'lukai diri',
  'ingin mati',
  'tidak kuat lagi',
  'putus asa',
  'mengakhiri hidup',
  'dipukuli',
  'ancaman fisik',
  'tolong bahaya',
  'terancam',
  'darurat',
];

const List<String> _personalOrEmotionalKeywords = <String>[
  'dibully',
  'dirundung',
  'bullying',
  'perundungan',
  'diejek',
  'dikucilkan',
  'diancam',
  'ditampar',
  'sedih',
  'cemas',
  'takut',
  'stres',
  'stress',
  'capek',
  'lelah',
  'nangis',
  'menangis',
  'marah',
  'kesal',
  'kesepian',
  'bingung',
  'tertekan',
  'khawatir',
  'overthinking',
  'curhat',
  'cerita',
  'perasaan',
  'rasanya',
  'hobi',
  'hobiku',
  'hobby',
  'kesukaanku',
  'aku suka',
  'saya suka',
  'dimarahin',
  'dimarahi',
  'nilai jelek',
  'teman',
  'keluarga',
  'orang tua',
  'guru bk',
];

final RegExp _promptInjectionPattern = RegExp(
  r'\b(abaikan\s+instruksi|lupakan\s+instruksi|lupakan\s+aturan|abaikan\s+aturan|ignore\s+previous\s+instructions|ignore\s+all\s+instructions|ignore\s+your\s+instructions|bypass\s+aturan|jailbreak|developer\s+mode|system\s+prompt|ubah\s+peranmu|ganti\s+peran|keluar\s+dari\s+karakter|berperan\s+sebagai\s+(?:guru|tutor|asisten|kalkulator|programmer|ai\s+umum|chatgpt)|jadilah\s+(?:guru|tutor|asisten\s+umum|kalkulator|programmer)|act\s+as\s+a|pretend\s+you\s+are)\b',
);

final RegExp _explicitRequestIntentPattern = RegExp(
  r'(?:\b(kasih|beri|berikan|tuliskan|tulis|buatkan|bikinkan|tutorial|hitung|hitungkan|selesaikan|selesain|kerjakan|kerjain|jawab|jawabkan|carikan|tentukan|jelaskan|jelasin|sebutkan|rangkum|rangkumkan|ringkas|ringkaskan|terjemahkan|terjemahin|translate|debug|perbaiki|dong)\b|\b(apa\s+(?:rumus|itu|pengertian|definisi)|berapa\s+(?:hasil|nilai|rumus)|gimana\s+rumus|bagaimana\s+cara\s+menghitung)\b|\?)',
);

final RegExp _explicitFormulaDemandStartPattern = RegExp(
  r'\b(kasih|beri(?:kan)?|tulis(?:kan)?|sebut(?:kan)?|jelas(?:kan|in)?|cari(?:kan)?|tunjuk(?:kan)?|apa(?:\s+saja|\s+itu)?|berapa|gimana|bagaimana)\b.{0,45}\b(rumus|formula)\b',
);

final RegExp _explicitFormulaDemandEndPattern = RegExp(
  r'\b(rumus|formula)\b.{0,45}(?:\b(?:apa|berapa|gimana|bagaimana|dong)\b|\?)',
);

final RegExp _formulaWithSubjectPattern = RegExp(
  r'\b(rumus|formula)\b.{0,45}\b(matematika|mtk|fisika|kimia|ekonomi|akuntansi|pythagoras|pitagoras|luas|keliling|volume|kecepatan|percepatan|gaya|energi|daya|usaha|tekanan|kalor|suhu|massa\s+jenis|gravitasi|ohm|mol|molaritas|integral|turunan|diferensial|trigonometri|sinus|cosinus|tangen|logaritma|matriks|vektor|peluang|statistika|rata-rata|median|modus|aljabar|persamaan|kuadrat|segitiga|lingkaran|persegi|trapesium|kubus|balok|tabung|kerucut|limas|prisma|bola|aritmatika|geometri|excel|vlookup|hlookup)\b',
);

final RegExp _subjectBeforeFormulaPattern = RegExp(
  r'\b(matematika|mtk|fisika|kimia|ekonomi|akuntansi|pythagoras|pitagoras|luas|keliling|volume|kecepatan|percepatan|gaya|energi|daya|usaha|tekanan|kalor|suhu|massa\s+jenis|gravitasi|ohm|mol|molaritas|integral|turunan|diferensial|trigonometri|sinus|cosinus|tangen|logaritma|matriks|vektor|peluang|statistika|rata-rata|median|modus|aljabar|persamaan|kuadrat|segitiga|lingkaran|persegi|trapesium|kubus|balok|tabung|kerucut|limas|prisma|bola|aritmatika|geometri|excel|vlookup|hlookup)\b.{0,35}\b(rumus|formula)\b',
);

final RegExp _explicitCalculationPattern = RegExp(
  r'\b(hitung(?:kan)?|kalkulasi|tentukan\s+(?:nilai|hasil|akar|turunan|integral|limit|luas|volume|keliling)|selesaikan\s+(?:persamaan|soal|integral|turunan|matematika)|berapa\s+(?:hasil|nilai)\s+(?:dari\s+)?[\d(])\b',
);

final RegExp _algebraicEquationPattern = RegExp(
  r'(?:^|[\s(=])\d*\s*[xyz]\s*(?:\^\s*\d+\s*)?[+\-*/=]\s*\d+',
);

final RegExp _mathFunctionCallPattern = RegExp(
  r'\b(?:sqrt|sin|cos|tan|log|ln)\s*\(\s*[\dxyz]',
);

final RegExp _strongArithmeticPattern = RegExp(
  r'(?:^|[\s(=])\d+(?:[.,]\d+)?\s*(?:[*×÷^]|(?:\s*[+]\s*)|(?:\s+x\s+))\s*\d+(?:[.,]\d+)?',
);

final RegExp _spacedSlashMinusArithmeticPattern = RegExp(
  r'(?:^|[\s(=])\d+(?:[.,]\d+)?\s+(?:/|-)\s+\d+(?:[.,]\d+)?',
);

final RegExp _advancedMathConceptPattern = RegExp(
  r'\b(teorema\s+pythagoras|teorema\s+pitagoras|integral\s+tentu|integral\s+tak\s+tentu|turunan\s+pertama|persamaan\s+kuadrat|sistem\s+persamaan\s+linear|spldv|spltv|deret\s+aritmatika|deret\s+geometri|determinan\s+matriks|matriks\s+invers)\b',
);

final RegExp _homeworkSolvingPattern = RegExp(
  r'\b(kerjakan|kerjain|selesaikan|selesain|jawab(?:kan)?|bantu\s+(?:kerjakan|kerjain|ngerjain|jawab|selesaikan|hitung))\b.{0,40}\b(pr|tugas|soal|ujian|ulangan|kuis|matematika|mtk|fisika|kimia|biologi|ekonomi|akuntansi|geografi|sejarah|sosiologi|ppkn|pkn|ipa|ips|bahasa\s+inggris|bahasa\s+indonesia)\b',
);

final RegExp _academicWritingPattern = RegExp(
  r'\b(buatkan|bikinkan|tulis(?:kan)?|cari(?:kan)?|rangkum(?:kan)?|ringkas(?:kan)?)\b.{0,40}\b(esai|essay|makalah|paper|karya\s+ilmiah|skripsi|laporan\s+praktikum|rangkuman\s+(?:bab|materi|pelajaran|buku)|presentasi|slide\s+ppt|ppt|pidato|puisi|pantun|cerpen|kliping|ringkasan\s+materi)\b',
);

final RegExp _scienceTheoryExplanationPattern = RegExp(
  r'\b(jelaskan|jelasin|apa\s+itu|apa\s+pengertian|definisi|sebutkan|tuliskan)\b.{0,40}\b(hukum\s+newton|teori\s+relativitas|fotosintesis|respirasi\s+sel|mitosis|meiosis|tabel\s+periodik|stoikiometri|atom|elektron|proton|neutron|sel\s+eukariotik|sel\s+prokariotik|ekosistem|rantai\s+makanan|termodinamika|elektromagnetik|tata\s+surya|planet|perang\s+dunia|revolusi\s+industri|inflasi|deflasi|produk\s+domestik\s+bruto|pdb|gdp|uud\s+1945|sejarah\s+kemerdekaan)\b',
);

final RegExp _directAnswerSeekingPattern = RegExp(
  r'\b(kunci\s+jawaban|pembahasan\s+soal|cara\s+menghitung)\b',
);

final RegExp _sampleProblemPattern = RegExp(r'\bcontoh\s+soal\b');

final RegExp _codingRequestPattern = RegExp(
  r'\b(buatkan|bikinkan|tulis(?:kan)?|kasih|beri(?:kan)?|contoh|perbaiki|debug|fix|bantu\s+(?:buat|bikin|debug|perbaiki|coding|koding)|jelaskan|cara\s+(?:buat|bikin|membuat|install|instal|deploy))\b.{0,45}\b(kode|code|koding|coding|script|skrip|program|algoritma|fungsi|function|query|sql|regex|rest\s+api|api|website|html|css|javascript|typescript|python|java|dart|flutter|react|vue|angular|c\+\+|c#|php|laravel|node\.?js|golang|rust|kotlin|swift|git|docker|database|mysql|postgresql)\b',
);

final RegExp _rawCodeSnippetPattern = RegExp(
  r"""(?:\bdef\s+\w+\s*\(|\bfunction\s+\w+\s*\(|\bconsole\.log\s*\(|\bselect\s+.+\s+from\s+\w+|\bimport\s+[\w{},\s]+\s+from\s+["']|\bvoid\s+main\s*\(|#include\s*<|public\s+static\s+void\s+main|```)""",
);

final RegExp _translationRequestPattern = RegExp(
  r'\b(terjemahkan|terjemahin|translate|artinya\s+dalam\s+bahasa|bahasa\s+(?:inggris|jepang|korea|arab|mandarin|jerman|prancis|spanyol)nya)\b',
);

final RegExp _explicitRecipeRequestPattern = RegExp(
  r'(?:^\s*resep\b|\b(?:kasih|beri(?:kan)?|tulis(?:kan)?|cari(?:kan)?|bagi(?:kan)?|apa)\b.{0,25}\bresep\b)',
);

final RegExp _namedRecipePattern = RegExp(
  r'\bresep\s+(?:nasi|mie|mi|ayam|ikan|daging|soto|bakso|rendang|sate|kue|bolu|brownies|seblak|martabak|es|kopi|minuman|masakan|makanan)\b',
);

final RegExp _culinaryHowToPattern = RegExp(
  r'\b(?:cara\s+(?:membuat|memasak|masak|bikin)|tutorial(?:\s+(?:membuat|memasak|masak|bikin))?)\s+(?:nasi\s+goreng|mie\s+goreng|kue|bolu|brownies|rendang|soto|bakso|seblak|kopi|masakan|makanan|slime)\b',
);

final RegExp _generalTriviaFinancePattern = RegExp(
  r'\b(siapa\s+(?:presiden|penemu|raja|perdana\s+menteri|pencipta|pemenang|pemain)|apa\s+(?:ibu\s+kota|ibukota|mata\s+uang|bendera|lagu\s+kebangsaan)|berapa\s+(?:luas\s+negara|populasi|jumlah\s+penduduk|jarak\s+bumi|harga\s+(?:saham|bitcoin|btc|eth|emas|crypto|kripto|dolar|dollar))|prediksi\s+(?:skor|pertandingan|bola|togel|saham|crypto|kripto)|ramalan\s+(?:cuaca|zodiak|bintang)|cuaca\s+.{0,25}hari\s+ini|berita\s+(?:terkini|terbaru|hari\s+ini)|kurs\s+(?:dollar|dolar|rupiah)|cara\s+(?:trading|investasi|daftar\s+saham|hack|bobol|cheat))\b',
);

final RegExp _businessWritingPattern = RegExp(
  r'\b(buatkan|bikinkan|tulis(?:kan)?)\b.{0,35}\b(cv|resume|surat\s+lamaran|caption\s+jualan|iklan\s+produk|skrip\s+promosi|business\s+plan|proposal\s+usaha|daftar\s+harga)\b',
);

bool _hasCrisisSafetySignal(String trimmed, String lower) {
  if (detectCrisisRiskLevel(trimmed) == CrisisRiskLevel.crisis) {
    return true;
  }
  return _urgentSafetyPhrases.any(lower.contains);
}

bool _hasPersonalOrEmotionalContext(String lower) {
  return _personalOrEmotionalKeywords.any(lower.contains);
}

bool _hasExplicitRequestIntent(String lower) {
  return _explicitRequestIntentPattern.hasMatch(lower);
}

CurhaiTopicValidationResult _reject(CurhaiTopicRejectionCategory category) {
  return CurhaiTopicValidationResult.rejected(
    category: category,
    refusalMessage: curhaiRefusalMessageForCategory(category),
  );
}

/// Validates whether [text] stays within CurhAI's bullying/emotional/personal scope.
CurhaiTopicValidationResult validateCurhaiTopic(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const CurhaiTopicValidationResult.allowed();
  }

  final lower = trimmed.toLowerCase();

  // Priority 0: Safety-first override so crisis or urgent physical danger
  // always passes through to empathetic support and SOS tools.
  if (_hasCrisisSafetySignal(trimmed, lower)) {
    return const CurhaiTopicValidationResult.allowed();
  }

  // Priority 1: Prompt injection / role hijack.
  if (_promptInjectionPattern.hasMatch(lower)) {
    return _reject(CurhaiTopicRejectionCategory.promptInjection);
  }

  final hasPersonalContext = _hasPersonalOrEmotionalContext(lower);
  final hasRequestIntent = _hasExplicitRequestIntent(lower);

  // Priority 2A: Math formulas, arithmetic, and equations.
  if (_explicitFormulaDemandStartPattern.hasMatch(lower) ||
      _explicitFormulaDemandEndPattern.hasMatch(lower) ||
      _explicitCalculationPattern.hasMatch(lower) ||
      _algebraicEquationPattern.hasMatch(lower) ||
      _mathFunctionCallPattern.hasMatch(lower) ||
      _strongArithmeticPattern.hasMatch(lower)) {
    return _reject(CurhaiTopicRejectionCategory.mathFormula);
  }

  if ((_formulaWithSubjectPattern.hasMatch(lower) ||
          _subjectBeforeFormulaPattern.hasMatch(lower) ||
          _advancedMathConceptPattern.hasMatch(lower)) &&
      (!hasPersonalContext || hasRequestIntent)) {
    return _reject(CurhaiTopicRejectionCategory.mathFormula);
  }

  if (_spacedSlashMinusArithmeticPattern.hasMatch(lower) &&
      (!hasPersonalContext || hasRequestIntent || lower.contains('='))) {
    return _reject(CurhaiTopicRejectionCategory.mathFormula);
  }

  // Priority 2B: Academic homework solving & science/encyclopedia requests.
  if (_homeworkSolvingPattern.hasMatch(lower) ||
      _academicWritingPattern.hasMatch(lower) ||
      _scienceTheoryExplanationPattern.hasMatch(lower) ||
      _directAnswerSeekingPattern.hasMatch(lower)) {
    return _reject(CurhaiTopicRejectionCategory.academicHomework);
  }

  if (_sampleProblemPattern.hasMatch(lower) &&
      (!hasPersonalContext || hasRequestIntent)) {
    return _reject(CurhaiTopicRejectionCategory.academicHomework);
  }

  // Priority 2C: Coding / programming / technical assistance.
  if (_codingRequestPattern.hasMatch(lower) ||
      _rawCodeSnippetPattern.hasMatch(lower)) {
    return _reject(CurhaiTopicRejectionCategory.codingTech);
  }

  // Priority 2D: General assistant, trivia, recipes, translation, finance.
  if (_translationRequestPattern.hasMatch(lower) ||
      _explicitRecipeRequestPattern.hasMatch(lower) ||
      _generalTriviaFinancePattern.hasMatch(lower) ||
      _businessWritingPattern.hasMatch(lower)) {
    return _reject(CurhaiTopicRejectionCategory.generalOffTopic);
  }

  if ((_namedRecipePattern.hasMatch(lower) ||
          _culinaryHowToPattern.hasMatch(lower)) &&
      (!hasPersonalContext || hasRequestIntent)) {
    return _reject(CurhaiTopicRejectionCategory.generalOffTopic);
  }

  return const CurhaiTopicValidationResult.allowed();
}
