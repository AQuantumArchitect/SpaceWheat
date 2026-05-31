class_name PerformanceOptimizer
extends Node


## Smart performance optimization based on hardware detection
##
## - Detects true software rasterizers and lowers presentation pressure
## - Keeps VSYNC enabled for real GPUs
## - Allows user override via settings
## - Logs decisions for debugging

static func detect_software_renderer() -> bool:
	# Returns true for software rasterizers, not just Mesa-based drivers.
	var gpu_name = RenderingServer.get_video_adapter_name().to_lower()
	var vendor_name = RenderingServer.get_video_adapter_vendor().to_lower()
	var is_software = (
		gpu_name.is_empty() or
		"llvmpipe" in gpu_name or
		"lavapipe" in gpu_name or
		"swiftshader" in gpu_name or
		"softpipe" in gpu_name or
		"software" in gpu_name or
		"microsoft basic render" in gpu_name or
		"swiftshader" in vendor_name or
		gpu_name == "unknown"
	)
	return is_software


static func optimize_for_platform() -> void:
	# Auto-configure performance settings based on detected hardware.
	var is_software_render = detect_software_renderer()
	var gpu_name = RenderingServer.get_video_adapter_name()
	var is_opengl_backend = not RenderingServer.get_rendering_device()
	var backend_name = "OpenGL compatibility" if is_opengl_backend else "RenderingDevice"

	# Log detection
	if is_software_render:
		VerboseHelper.info("perf", "gpu", "Software rendering detected on %s: %s" % [backend_name, gpu_name])
		VerboseHelper.info("perf", "vsync", "Reducing presentation pressure for software rasterizer")
	elif is_opengl_backend:
		VerboseHelper.info("perf", "gpu", "Hardware renderer detected on %s: %s" % [backend_name, gpu_name])
		VerboseHelper.info("perf", "vsync", "OpenGL backend detected: runtime VSYNC switching may be limited")
	else:
		VerboseHelper.info("perf", "gpu", "Hardware renderer detected on %s: %s" % [backend_name, gpu_name])
		VerboseHelper.info("perf", "vsync", "Keeping VSYNC enabled for smooth presentation")

	# Apply settings
	if is_software_render:
		# Software rendering: cap FPS to avoid runaway CPU/present churn.
		if not is_opengl_backend:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 30
		VerboseHelper.info("perf", "fps", "VSYNC: OFF (software rendering), FPS cap: 30")
	else:
		# Hardware renderer: prefer VSYNC when the backend can control it.
		if is_opengl_backend:
			Engine.max_fps = 60
			VerboseHelper.info("perf", "fps", "OpenGL mode - FPS cap: 60")
		else:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			VerboseHelper.info("perf", "fps", "VSYNC: ON (hardware GPU)")


static func get_performance_profile() -> Dictionary:
	# Return hardware profile with recommended settings.
	var is_software = detect_software_renderer()
	var gpu_name = RenderingServer.get_video_adapter_name()

	return {
		"gpu_name": gpu_name,
		"is_software_rendering": is_software,
		"recommended_vsync": DisplayServer.VSYNC_DISABLED if is_software else DisplayServer.VSYNC_ENABLED,
		"target_fps": 30 if is_software else 60,
	}
