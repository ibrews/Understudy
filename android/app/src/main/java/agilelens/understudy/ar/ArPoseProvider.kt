package agilelens.understudy.ar

import agilelens.understudy.model.Pose
import android.app.Activity
import android.content.Context
import android.util.Log
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Camera
import com.google.ar.core.Config
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.UnavailableException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.atan2

/**
 * ArPoseProvider
 *
 * Wraps an ARCore Session and produces a stream of Pose + tracking-quality updates
 * at ~10 Hz (matching the iOS Transport.swift throttle).
 *
 * ARCore uses an OpenGL convention (Y-up, -Z forward, right-handed). The pose
 * matches Swift's `Pose(x,y,z,yaw)`: yaw is rotation about +Y in radians.
 * We extract yaw from the camera's forward vector (-Z column of the rotation matrix):
 *     forward = (-R[0,2], -R[1,2], -R[2,2])
 *     yaw     = atan2(forward.x, forward.z)
 *
 * This is a "headless" provider — it does NOT own a GLSurfaceView. For the demo
 * we're happy to drive the UI from pose samples alone; a visible camera preview
 * can be wired in later with a GLSurfaceView + BackgroundRenderer if desired.
 */
class ArPoseProvider(
    private val appContext: Context,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
) {
    private val tag = "UnderstudyAR"

    enum class Availability { Unknown, Unavailable, NeedsInstall, Supported }

    data class Sample(val pose: Pose, val quality: Float, val tracking: TrackingState)

    private var session: Session? = null
    private var pollJob: Job? = null
    private var installRequested: Boolean = false

    private val _latest = MutableStateFlow<Sample?>(null)
    val latest: StateFlow<Sample?> = _latest.asStateFlow()

    private val _availability = MutableStateFlow(Availability.Unknown)
    val availability: StateFlow<Availability> = _availability.asStateFlow()

    /** Expose the underlying ARCore Session so the stage renderer can share it. */
    fun session(): Session? = session

    @Volatile
    private var _depthSupported: Boolean = false

    /** True when `Config.DepthMode.AUTOMATIC` is supported on this device. */
    fun isDepthSupported(): Boolean = _depthSupported

    /** Latest view matrix captured from the camera (16 floats, column-major OpenGL). */
    @Volatile
    var lastViewMatrix: FloatArray = FloatArray(16).also { android.opengl.Matrix.setIdentityM(it, 0) }
        private set

    /** Latest projection matrix with near=0.1, far=100.0 (16 floats, column-major). */
    @Volatile
    var lastProjectionMatrix: FloatArray = FloatArray(16).also { android.opengl.Matrix.setIdentityM(it, 0) }
        private set

    /**
     * Try to create and resume a Session. Must be called on an Activity with
     * CAMERA permission already granted. If ARCore needs installing this will
     * request the install and return false; call again after the install flow.
     */
    fun resume(activity: Activity): Boolean {
        try {
            when (ArCoreApk.getInstance().requestInstall(activity, !installRequested)) {
                ArCoreApk.InstallStatus.INSTALL_REQUESTED -> {
                    installRequested = true
                    _availability.value = Availability.NeedsInstall
                    return false
                }
                ArCoreApk.InstallStatus.INSTALLED -> { /* good */ }
            }
            val s = session ?: Session(activity).also {
                val depthSupported = try {
                    it.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
                } catch (_: Throwable) { false }
                val config = Config(it).apply {
                    updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                    focusMode = Config.FocusMode.AUTO
                    // AUTOMATIC depth when the device supports it; otherwise DISABLED.
                    // The DepthRenderer no-ops gracefully when depth frames are unavailable.
                    depthMode = if (depthSupported) Config.DepthMode.AUTOMATIC else Config.DepthMode.DISABLED
                    planeFindingMode = Config.PlaneFindingMode.DISABLED
                    lightEstimationMode = Config.LightEstimationMode.DISABLED
                }
                it.configure(config)
                _depthSupported = depthSupported
            }
            session = s
            s.resume()
            _availability.value = Availability.Supported
            startPolling()
            return true
        } catch (t: CameraNotAvailableException) {
            Log.w(tag, "camera not available: ${t.message}")
            _availability.value = Availability.Unavailable
            return false
        } catch (t: UnavailableException) {
            Log.w(tag, "AR unavailable: ${t.message}")
            _availability.value = Availability.Unavailable
            return false
        } catch (t: Throwable) {
            Log.w(tag, "AR resume failed: ${t.message}")
            _availability.value = Availability.Unavailable
            return false
        }
    }

    fun pause() {
        pollJob?.cancel(); pollJob = null
        try { session?.pause() } catch (_: Throwable) {}
    }

    fun close() {
        pollJob?.cancel(); pollJob = null
        try { session?.close() } catch (_: Throwable) {}
        session = null
        scope.cancel()
    }

    private fun startPolling() {
        if (pollJob?.isActive == true) return
        pollJob = scope.launch {
            while (isActive) {
                pollOnce()
                delay(100L) // 10 Hz
            }
        }
    }

    private fun pollOnce() {
        val s = session ?: return
        try {
            val frame = s.update() ?: return
            val cam: Camera = frame.camera
            val pose = cam.pose

            // translation[0..2] = x,y,z
            val tx = pose.tx(); val ty = pose.ty(); val tz = pose.tz()

            // Extract the camera-forward vector (world-space) from the rotation.
            // ARCore Pose has a 4x4 matrix: rotate an OpenGL -Z forward into world.
            val forward = FloatArray(3)
            val localForward = floatArrayOf(0f, 0f, -1f)
            pose.rotateVector(localForward, 0, forward, 0)
            val yaw = atan2(forward[0], forward[2]).toFloat()  // rotation about +Y

            val quality: Float = when (cam.trackingState) {
                TrackingState.TRACKING -> 1.0f
                TrackingState.PAUSED -> 0.4f
                TrackingState.STOPPED -> 0.0f
                else -> 0.0f
            }

            // Capture matrices for the stage overlay. These are only meaningful while
            // tracking; a stale matrix is fine because the overlay draws transparently.
            try {
                val vm = FloatArray(16)
                val pm = FloatArray(16)
                cam.getViewMatrix(vm, 0)
                cam.getProjectionMatrix(pm, 0, 0.1f, 100.0f)
                lastViewMatrix = vm
                lastProjectionMatrix = pm
            } catch (_: Throwable) { /* keep previous */ }

            _latest.value = Sample(
                pose = Pose(x = tx, y = ty, z = tz, yaw = yaw),
                quality = quality,
                tracking = cam.trackingState
            )
        } catch (t: Throwable) {
            // transient — ARCore frames can be dropped while the camera spins up
        }
    }

    companion object {
        /** Check whether ARCore is available on this device without side effects. */
        fun checkAvailability(ctx: Context): Availability {
            val avail = ArCoreApk.getInstance().checkAvailability(ctx)
            return when (avail) {
                ArCoreApk.Availability.SUPPORTED_INSTALLED -> Availability.Supported
                ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD,
                ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED -> Availability.NeedsInstall
                ArCoreApk.Availability.UNSUPPORTED_DEVICE_NOT_CAPABLE -> Availability.Unavailable
                ArCoreApk.Availability.UNKNOWN_CHECKING,
                ArCoreApk.Availability.UNKNOWN_ERROR,
                ArCoreApk.Availability.UNKNOWN_TIMED_OUT -> Availability.Unknown
                else -> Availability.Unknown
            }
        }
    }
}
