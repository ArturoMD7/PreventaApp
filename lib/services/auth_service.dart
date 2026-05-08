import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Iniciar sesión con Google
  Future<AuthResponse> signInWithGoogle() async {
    const webClientId = '355707615598-dhmrr93ojqdd7ot34oum92rpnv6cq7bi.apps.googleusercontent.com'; 

    final GoogleSignIn googleSignIn = GoogleSignIn(
      serverClientId: webClientId,
      // clientId: se usaría aquí si tuvieras un ID para iOS
    );
    
    final googleUser = await googleSignIn.signIn();
    final googleAuth = await googleUser!.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) {
      throw 'No Access Token found.';
    }
    if (idToken == null) {
      throw 'No ID Token found.';
    }

    return _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
    await _supabase.auth.signOut();
  }

  /// Usuario actual
  User? get currentUser => _supabase.auth.currentUser;
}
