import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';
import 'local_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create Firebase user
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      debugPrint('✅ User created: ${userCredential.user?.uid}');

      // Wait a moment for Firebase user to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));

      // Register user with backend
      try {
        await _registerWithBackend(name: name, email: email);
      } catch (backendError) {
        debugPrint('⚠️ Backend registration failed, but Firebase auth succeeded: $backendError');
        // Don't throw - user is authenticated in Firebase, backend can sync later
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Sign up error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Sign up error: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint('✅ User signed in: ${userCredential.user?.uid}');
      
      // Wait a moment for Firebase user to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Sign in error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Sign in error: $e');
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('❌ Google sign-in cancelled');
        return null; // User cancelled
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      debugPrint('✅ Firebase sign-in successful: ${userCredential.user?.uid}');

      // Wait a moment for Firebase user to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if this is a new user and register with backend
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        debugPrint('🆕 New user detected, registering with backend...');
        try {
          await _registerWithBackend(
            name: userCredential.user?.displayName ?? 'User',
            email: userCredential.user?.email ?? '',
          );
        } catch (backendError) {
          debugPrint('⚠️ Backend registration failed, but Firebase auth succeeded: $backendError');
          // Don't throw - user is authenticated in Firebase, backend can sync later
        }
      } else {
        debugPrint('👤 Existing user signed in');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Google sign-in Firebase error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Google sign-in error: $e');
      // Provide more specific error message
      if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection and try again.');
      } else if (e.toString().contains('INTERNAL_ERROR')) {
        throw Exception('Google Sign-In configuration error. Please try email sign-in or contact support.');
      }
      rethrow;
    }
  }

  // Sign in with Apple (iOS only)
  Future<UserCredential?> signInWithApple() async {
    if (!Platform.isIOS) {
      throw UnsupportedError('Apple Sign-In is only available on iOS');
    }

    try {
      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create OAuth credential
      final oAuthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(oAuthCredential);

      debugPrint('✅ Firebase sign-in successful: ${userCredential.user?.uid}');

      // Wait a moment for Firebase user to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if this is a new user and register with backend
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        debugPrint('🆕 New user detected, registering with backend...');
        
        // Build name from Apple credential
        String name = 'User';
        if (appleCredential.givenName != null || appleCredential.familyName != null) {
          name = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
        }

        try {
          await _registerWithBackend(
            name: name.isEmpty ? 'User' : name,
            email: userCredential.user?.email ?? appleCredential.email ?? '',
          );
        } catch (backendError) {
          debugPrint('⚠️ Backend registration failed, but Firebase auth succeeded: $backendError');
          // Don't throw - user is authenticated in Firebase, backend can sync later
        }
      } else {
        debugPrint('👤 Existing user signed in');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Apple sign-in Firebase error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Apple sign-in error: $e');
      rethrow;
    }
  }

  // Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('✅ Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Password reset error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Password reset error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      debugPrint('✅ User signed out');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      rethrow;
    }
  }

  // Delete account (Firebase + Backend)
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // Delete Firebase user
      await user.delete();

      // Sign out from Google if signed in
      await _googleSignIn.signOut();

      debugPrint('✅ Account deleted');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please sign in again to delete your account');
      }
      debugPrint('❌ Delete account error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Delete account error: $e');
      rethrow;
    }
  }

  // Get Firebase ID token for API calls
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('❌ Get ID token error: $e');
      return null;
    }
  }

  // Register user with backend
  Future<void> _registerWithBackend({required String name, required String email}) async {
    try {
      // Store identity in local storage (same format as onboarding)
      await LocalStorageService.saveSetting('userName', name);
      await LocalStorageService.saveSetting('userAge', 0); // Can be updated later
      await LocalStorageService.saveSetting('burningQuestion', ''); // Can be updated later

      debugPrint('✅ User registered locally');
    } catch (e) {
      debugPrint('⚠️ Backend registration error: $e');
      // Don't throw - allow Firebase auth to succeed even if backend fails
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}

