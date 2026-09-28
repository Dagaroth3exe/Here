import 'package:flutter/foundation.dart';

/// Whether you're Reachable right now — the status switch on Home. The whole
/// app drains to greyscale while it's off (see [AppColors.resolveAccent]),
/// so it's shared rather than private to the Home screen.
class ReachabilityController {
  ReachabilityController._();

  static final ValueNotifier<bool> on = ValueNotifier(true);
}
