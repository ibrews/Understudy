package agilelens.understudy.glasses

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.xr.projected.ProjectedContext
import androidx.xr.projected.experimental.ExperimentalProjectedApi

/**
 * Fires the `GlassesTeleprompterActivity` onto the paired AI Glasses display.
 * Uses the Jetpack XR projected-context API, same pattern as Alex's
 * gemini-live-todo `TeleprompterControlActivity.onStart`.
 *
 * Caller should gate with `isProjectedDeviceConnectedFlow` so the UI only
 * shows the "Open on Glasses" button when glasses are paired.
 */
object GlassesLauncher {

    private const val TAG = "GlassesLauncher"

    @OptIn(ExperimentalProjectedApi::class)
    fun launch(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            Log.w(TAG, "Projected context requires API 35 (VanillaIceCream) or later.")
            return false
        }
        return try {
            val projectedContext = ProjectedContext.createProjectedDeviceContext(activity)
            val options = ProjectedContext.createProjectedActivityOptions(projectedContext)
            val intent = Intent(activity, GlassesTeleprompterActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent, options.toBundle())
            true
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to launch teleprompter on glasses: ${t.message}", t)
            false
        }
    }
}
