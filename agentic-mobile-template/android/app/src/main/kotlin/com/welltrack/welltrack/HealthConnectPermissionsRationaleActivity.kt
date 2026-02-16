package com.welltrack.welltrack

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * Required by Health Connect for Play Store compliance.
 * Shows the app's privacy policy when the user taps
 * "Learn more" on the Health Connect permission dialog.
 *
 * This activity launches the main Flutter app which handles
 * routing to the health permissions rationale screen.
 */
class HealthConnectPermissionsRationaleActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The Flutter app handles displaying the rationale via GoRouter
    }
}
