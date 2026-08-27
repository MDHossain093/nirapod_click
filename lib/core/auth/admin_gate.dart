import 'package:firebase_auth/firebase_auth.dart';

import 'admin_uids.dart';

/// Returns `true` if the supplied [user] is allowed to publish
/// admin-published alerts.
///
/// `null` user (signed-out) is never an admin. Anonymous users are
/// never admins.
///
/// Implementation note: see `lib/core/auth/admin_uids.dart` for why
/// this is a compile-time list rather than a Firebase custom claim.
bool isAdmin(User? user) {
  if (user == null) return false;
  if (user.isAnonymous) return false;
  return kAdminUids.contains(user.uid);
}

/// Convenience overload for the common "current user" case.
bool isCurrentUserAdmin() => isAdmin(FirebaseAuth.instance.currentUser);
