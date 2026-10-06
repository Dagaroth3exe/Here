import 'package:url_launcher/url_launcher.dart';

import 'api_config.dart';

/// The privacy policy, served by the backend as a public page (the same URL
/// the app stores list), opened in the browser.
Uri get privacyPolicyUrl => Uri.parse('${ApiConfig.baseUrl}/privacy');

Future<void> openPrivacyPolicy() => launchUrl(privacyPolicyUrl, mode: LaunchMode.externalApplication);
