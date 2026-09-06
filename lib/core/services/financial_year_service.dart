class FinancialYearService {
  static String getCurrentFinancialYear({DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    // In India, Financial Year starts from April 1st
    int startYear;
    int endYear;
    
    if (targetDate.month >= 4) {
      startYear = targetDate.year;
      endYear = targetDate.year + 1;
    } else {
      startYear = targetDate.year - 1;
      endYear = targetDate.year;
    }
    
    // Format: YYYY-YY (e.g., 2024-25)
    final endYearShort = endYear.toString().substring(2);
    return '$startYear-$endYearShort';
  }

  static String generateDocumentNumber(String prefix, int counter, {DateTime? date}) {
    final fy = getCurrentFinancialYear(date: date);
    final paddedCounter = counter.toString().padLeft(4, '0');
    return '$prefix/$fy/$paddedCounter';
  }
}
