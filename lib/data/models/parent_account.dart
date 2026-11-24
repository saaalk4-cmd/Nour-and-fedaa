enum SignInMethod { google, email }

/// حساب ولي الأمر. في هذه المرحلة محلي على الجهاز، ويُستبدل بـFirebase Auth.
class ParentAccount {
  const ParentAccount({required this.method, this.email});

  final SignInMethod method;
  final String? email;
}
