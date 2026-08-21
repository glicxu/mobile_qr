final class QrMatrix {
  QrMatrix({
    required this.version,
    required this.maskPattern,
    required this.moduleCount,
    required Iterable<bool> modules,
  }) : modules = List<bool>.unmodifiable(modules) {
    if (this.modules.length != moduleCount * moduleCount) {
      throw ArgumentError.value(
        this.modules.length,
        'modules',
        'Expected ${moduleCount * moduleCount} modules.',
      );
    }
  }

  final int version;
  final int maskPattern;
  final int moduleCount;
  final List<bool> modules;

  bool isDark(int row, int column) {
    RangeError.checkValueInInterval(row, 0, moduleCount - 1, 'row');
    RangeError.checkValueInInterval(column, 0, moduleCount - 1, 'column');
    return modules[row * moduleCount + column];
  }
}
