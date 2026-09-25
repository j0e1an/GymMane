import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class WebAccount {
  const WebAccount({required this.id, this.email, this.name});

  final String id;
  final String? email;
  final String? name;
}

Future<WebAccount?> currentWebAccount() async {
  try {
    final response = await web.window
        .fetch('/auth/me'.toJS, web.RequestInit(credentials: 'include'))
        .toDart;
    if (response.status != 200) return null;
    final raw = jsonDecode((await response.text().toDart).toDart);
    if (raw is! Map) return null;
    final id = raw['sub'];
    if (id is! String || id.isEmpty) return null;
    final email = raw['email'];
    final name = raw['name'];
    return WebAccount(
      id: id,
      email: email is String && email.isNotEmpty ? email : null,
      name: name is String && name.isNotEmpty ? name : null,
    );
  } catch (_) {
    return null;
  }
}

void startGoogleSignIn() {
  web.window.location.assign('/auth/login');
}

void signOutWeb() {
  web.window.location.assign('/auth/logout');
}
