class WebAccount {
  const WebAccount({required this.id, this.email, this.name});

  final String id;
  final String? email;
  final String? name;
}

Future<WebAccount?> currentWebAccount() async => null;

void startGoogleSignIn() {}

void signOutWeb() {}
