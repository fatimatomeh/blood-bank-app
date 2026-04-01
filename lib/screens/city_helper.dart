// city_helper.dart
// ملف مشترك لتوحيد أسماء المدن - يُستخدم في جميع الصفحات

class CityHelper {
  // جميع المدن بصيغتها العربية الموحدة
  static const List<String> arabicCities = [
    "رام الله",
    "البيرة",
    "نابلس",
    "الخليل",
    "بيت لحم",
    "جنين",
    "طولكرم",
    "قلقيلية",
    "أريحا",
    "سلفيت",
    "طوباس",
  ];

  // خريطة تحويل أي صيغة للمدينة إلى الصيغة العربية الموحدة
  static const Map<String, String> _normalizeMap = {
    "ramallah": "رام الله",
    "رام الله": "رام الله",
    "al-bireh": "البيرة",
    "البيرة": "البيرة",
    "nablus": "نابلس",
    "نابلس": "نابلس",
    "hebron": "الخليل",
    "الخليل": "الخليل",
    "bethlehem": "بيت لحم",
    "بيت لحم": "بيت لحم",
    "jenin": "جنين",
    "جنين": "جنين",
    "tulkarm": "طولكرم",
    "طولكرم": "طولكرم",
    "qalqilya": "قلقيلية",
    "قلقيلية": "قلقيلية",
    "jericho": "أريحا",
    "أريحا": "أريحا",
    "salfit": "سلفيت",
    "سلفيت": "سلفيت",
    "tubas": "طوباس",
    "طوباس": "طوباس",
  };

  /// يحوّل أي صيغة لاسم المدينة إلى الاسم العربي الموحد
  static String normalize(String? city) {
    if (city == null || city.trim().isEmpty) return "";
    final key = city.trim().toLowerCase();
    // نحاول بالمفتاح الصغير أولاً ثم الأصلي
    return _normalizeMap[key] ?? _normalizeMap[city.trim()] ?? city.trim();
  }
}
