enum SignInMethod { google, email }

/// حساب ولي الأمر.
class ParentAccount {
  const ParentAccount({required this.method, this.email, this.uid});

  final SignInMethod method;
  final String? email;

  /// معرّف Firebase (null في الوضع المحلي التجريبي).
  final String? uid;

  bool get isLocal => uid == null;
}
