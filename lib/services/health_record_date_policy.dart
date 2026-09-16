class HealthRecordDatePolicy {
  HealthRecordDatePolicy._();

  static bool isVaccination(String type) =>
      type.trim().toLowerCase() == 'vaccination';

  static bool isDeworming(String type) =>
      type.trim().toLowerCase() == 'deworming';

  static bool requiresNextUpdate(String type) =>
      isVaccination(type) || isDeworming(type);

  static bool canEditNextUpdate(String type) => isDeworming(type);

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime vaccinationNextUpdate(DateTime dateIssued) {
    final issued = dateOnly(dateIssued);
    return DateTime(issued.year + 1, issued.month, issued.day);
  }

  static DateTime? parse(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final numeric = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
    if (numeric != null) {
      return _validDate(
        int.parse(numeric.group(3)!),
        int.parse(numeric.group(1)!),
        int.parse(numeric.group(2)!),
      );
    }

    const months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    final named = RegExp(
      r'^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$',
    ).firstMatch(text);
    if (named == null) return null;
    final month = months[named.group(1)!.toLowerCase()];
    if (month == null) return null;
    return _validDate(
      int.parse(named.group(3)!),
      month,
      int.parse(named.group(2)!),
    );
  }

  static String formatNumeric(DateTime value) {
    final date = dateOnly(value);
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  static String formatNamed(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final date = dateOnly(value);
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String? validate({
    required String type,
    required DateTime? dateIssued,
    required DateTime? nextUpdate,
    DateTime? today,
  }) {
    if (dateIssued == null) return 'Date Issued is required.';
    final currentDate = dateOnly(today ?? DateTime.now());
    final issued = dateOnly(dateIssued);
    if (issued.isAfter(currentDate)) {
      return 'Date Issued cannot be in the future.';
    }

    if (!requiresNextUpdate(type)) return null;
    if (nextUpdate == null) return 'Next Update is required.';
    if (!dateOnly(nextUpdate).isAfter(issued)) {
      return 'Next Update must be later than Date Issued.';
    }
    if (isVaccination(type) &&
        dateOnly(nextUpdate) != vaccinationNextUpdate(issued)) {
      return 'Vaccination Next Update must be one year after Date Issued.';
    }
    return null;
  }

  static DateTime? _validDate(int year, int month, int day) {
    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return value;
  }
}
