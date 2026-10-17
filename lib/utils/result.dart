// نتيجة عملية: نجاح بقيمة (Ok) أو فشل بخطأ (Err).
// تجبر كل من يستدعي العملية على التعامل مع الحالتين.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>._;
  const factory Result.error(Exception error) = Err<T>._;
}

final class Ok<T> extends Result<T> {
  const Ok._(this.value);

  final T value;

  @override
  String toString() => 'Result<$T>.ok($value)';
}

final class Err<T> extends Result<T> {
  const Err._(this.error);

  final Exception error;

  @override
  String toString() => 'Result<$T>.error($error)';
}

// يحوّل أي خطأ إلى Exception مع رسالة مفهومة
Exception asException(Object error) =>
    error is Exception ? error : Exception(error.toString());
