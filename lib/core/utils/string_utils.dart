/// Tiện ích xử lý chuỗi và so sánh tự nhiên (Natural Sorting)
class StringUtils {
  /// So sánh hai chuỗi theo thứ tự tự nhiên (Natural Sort Order).
  ///
  /// Chuỗi có chứa số sẽ được sắp xếp theo giá trị số thực tế:
  /// ví dụ: `6A1`, `6A2`, ..., `6A9`, `6A10`, `6A11`
  /// thay vì thứ tự từ điển thông thường (`6A1`, `6A10`, `6A11`, `6A2`).
  static int compareNatural(String a, String b) {
    if (identical(a, b) || a == b) return 0;
    if (a.isEmpty) return -1;
    if (b.isEmpty) return 1;

    final regExp = RegExp(r'(\d+)|(\D+)');
    final matchesA = regExp.allMatches(a).toList();
    final matchesB = regExp.allMatches(b).toList();

    final minLength =
        matchesA.length < matchesB.length ? matchesA.length : matchesB.length;

    for (int i = 0; i < minLength; i++) {
      final tokenA = matchesA[i].group(0)!;
      final tokenB = matchesB[i].group(0)!;

      if (tokenA == tokenB) continue;

      final isNumA = int.tryParse(tokenA) != null;
      final isNumB = int.tryParse(tokenB) != null;

      if (isNumA && isNumB) {
        final numA = BigInt.tryParse(tokenA) ?? BigInt.zero;
        final numB = BigInt.tryParse(tokenB) ?? BigInt.zero;
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;

        // Nếu cùng giá trị số nhưng khác độ dài (ví dụ "01" và "1"), chuỗi ngắn hơn xếp trước
        final lenCmp = tokenA.length.compareTo(tokenB.length);
        if (lenCmp != 0) return lenCmp;
      } else if (isNumA != isNumB) {
        // Số đứng trước chữ cái (tương đồng bảng mã ASCII 0-9 trước A-Z)
        return isNumA ? -1 : 1;
      } else {
        final cmp = tokenA.toLowerCase().compareTo(tokenB.toLowerCase());
        if (cmp != 0) return cmp;

        // Phân biệt chữ hoa / chữ thường nếu cùng từ
        final caseCmp = tokenA.compareTo(tokenB);
        if (caseCmp != 0) return caseCmp;
      }
    }

    return matchesA.length.compareTo(matchesB.length);
  }
}
