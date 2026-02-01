## ComputeBackendSelector - Cross-platform compute path selection
##
## Intelligently selects the best compute backend for force calculations:
## 1. GPU compute (Vulkan/WebGPU/Metal) - if hardware available and fast
## 2. C++ native (CPU, SIMD optimized) - if GPU unavailable or slow
## 3. GDScript fallback - if native unavailable
##
## Includes performance benchmarking and platform detection.

extends RefCounted

class_name ComputeBackendSelector

enum Backend {
	UNKNOWN,
	GPU_COMPUTE,    # Vulkan/WebGPU compute shaders
	NATIVE_CPU,     # C++ GDExtension
	GDSCRIPT_CPU    # Pure GDScript fallback
}

## Platform detection
enum Platform {
	DESKTOP_VULKAN,   # Windows/Linux/Mac with Vulkan
	DESKTOP_D3D12,    # Windows with DirectX 12
	WEB_WEBGPU,       # Web with WebGPU
	MOBILE_VULKAN,    # Android with Vulkan
	MOBILE_METAL,     # iOS with Metal
	HEADLESS,         # Server/CI
	UNKNOWN
}

var selected_backend: Backend = Backend.UNKNOWN
var current_platform: Platform = Platform.UNKNOWN
var gpu_device_name: String = ""
var is_software_renderer: bool = false

## Benchmark results (ms per 1000 nodes)
var gpu_benchmark_time: float = -1.0
var cpu_benchmark_time: float = -1.0

## Override for testing (set via command line or settings)
var force_backend: String = ""  # "gpu", "native", "gdscript", or ""

## Benchmark results (optional - can be set before selection)
var benchmark_results: Dictionary = {}  # From ComputeBenchmark


func _init(skip_selection: bool = false):
	"""Detect platform and optionally select backend.

	Args:
		skip_selection: If true, only detect platform (wait for benchmark)
	"""
	_detect_platform()
	if not skip_selection:
		_select_backend()


func _detect_platform() -> void:
	"""Detect what platform and rendering backend we're running on."""
	var renderer_name = RenderingServer.get_rendering_device()

	# Check if headless
	if DisplayServer.get_name() == "headless":
		current_platform = Platform.HEADLESS
		print("[ComputeSelector] Platform: HEADLESS - GPU compute unavailable")
		return

	# Check rendering backend
	var rendering_driver = ProjectSettings.get_setting("rendering/renderer/rendering_method", "")

	# Web platform
	if OS.has_feature("web"):
		current_platform = Platform.WEB_WEBGPU
		print("[ComputeSelector] Platform: WEB (WebGPU)")
		return

	# Mobile platforms
	if OS.has_feature("android"):
		current_platform = Platform.MOBILE_VULKAN
		print("[ComputeSelector] Platform: ANDROID (Vulkan)")
		return

	if OS.has_feature("ios"):
		current_platform = Platform.MOBILE_METAL
		print("[ComputeSelector] Platform: IOS (Metal via MoltenVK)")
		return

	# Desktop - check renderer
	if OS.has_feature("windows") or OS.has_feature("linux") or OS.has_feature("macos"):
		# Try to create RenderingDevice to detect backend
		var rd = RenderingServer.create_local_rendering_device()
		if rd:
			gpu_device_name = rd.get_device_name()

			# Check for software renderer
			if gpu_device_name.to_lower().contains("llvmpipe") or \
			   gpu_device_name.to_lower().contains("swiftshader") or \
			   gpu_device_name.to_lower().contains("software"):
				is_software_renderer = true
				print("[ComputeSelector] Software renderer detected: %s" % gpu_device_name)
			else:
				print("[ComputeSelector] Hardware GPU detected: %s" % gpu_device_name)

			rd.free()
			current_platform = Platform.DESKTOP_VULKAN
		else:
			print("[ComputeSelector] Platform: DESKTOP - No RenderingDevice available")
			current_platform = Platform.DESKTOP_VULKAN  # Assume Vulkan unavailable

	print("[ComputeSelector] Platform: %s" % Platform.keys()[current_platform])


func _select_backend() -> void:
	"""Select the best compute backend based on platform and capabilities."""

	# Check for forced backend (testing/debugging)
	if force_backend != "":
		_apply_forced_backend()
		return

	# Headless - CPU only
	if current_platform == Platform.HEADLESS:
		selected_backend = _try_native_cpu()
		return

	# Software renderer - skip GPU
	if is_software_renderer:
		print("[ComputeSelector] Software renderer detected - skipping GPU compute")
		selected_backend = _try_native_cpu()
		return

	# Try GPU compute for platforms that support it
	match current_platform:
		Platform.DESKTOP_VULKAN, Platform.DESKTOP_D3D12, \
		Platform.WEB_WEBGPU, Platform.MOBILE_VULKAN, Platform.MOBILE_METAL:
			# Check if GPU is actually faster (benchmark on first run)
			if _should_use_gpu():
				selected_backend = Backend.GPU_COMPUTE
				print("[ComputeSelector] Selected: GPU_COMPUTE")
			else:
				selected_backend = _try_native_cpu()
		_:
			selected_backend = _try_native_cpu()


func apply_benchmark_results(results: Dictionary) -> void:
	"""Apply benchmark results and re-select backend.

	Args:
		results: Dictionary from ComputeBenchmark.run_benchmark()
	"""
	benchmark_results = results
	print("[ComputeSelector] Applying benchmark results: winner=%s" % results.get("winner", "unknown"))
	_select_backend()


func _should_use_gpu() -> bool:
	"""Determine if GPU compute should be used (benchmark if needed)."""

	# If benchmark results available, use them
	if not benchmark_results.is_empty():
		var winner = benchmark_results.get("winner", "")
		if winner == "gpu":
			print("[ComputeSelector] Benchmark recommends GPU")
			return true
		elif winner == "tie":
			print("[ComputeSelector] Benchmark shows tie - using GPU to free CPU")
			return true
		else:
			print("[ComputeSelector] Benchmark recommends CPU")
			return false

	# Check if RenderingDevice is available
	var rd = RenderingServer.create_local_rendering_device()
	if not rd:
		print("[ComputeSelector] RenderingDevice unavailable - skipping GPU")
		return false

	var device_name = rd.get_device_name()
	rd.free()

	# Reject known software renderers
	if device_name.to_lower().contains("llvmpipe") or \
	   device_name.to_lower().contains("swiftshader"):
		print("[ComputeSelector] Software Vulkan detected (%s) - skipping GPU" % device_name)
		return false

	# Hardware GPU detected, but no benchmark - assume it's faster
	print("[ComputeSelector] Hardware GPU detected (no benchmark) - assuming faster")
	return true


func _try_native_cpu() -> Backend:
	"""Try to use C++ native engine, fallback to GDScript."""
	if ClassDB.class_exists("ForceGraphEngine"):
		print("[ComputeSelector] Selected: NATIVE_CPU (C++ GDExtension)")
		return Backend.NATIVE_CPU
	else:
		print("[ComputeSelector] Selected: GDSCRIPT_CPU (fallback)")
		return Backend.GDSCRIPT_CPU


func _apply_forced_backend() -> void:
	"""Apply user-forced backend selection."""
	match force_backend.to_lower():
		"gpu":
			selected_backend = Backend.GPU_COMPUTE
			print("[ComputeSelector] FORCED: GPU_COMPUTE")
		"native", "cpp":
			selected_backend = Backend.NATIVE_CPU
			print("[ComputeSelector] FORCED: NATIVE_CPU")
		"gdscript", "script":
			selected_backend = Backend.GDSCRIPT_CPU
			print("[ComputeSelector] FORCED: GDSCRIPT_CPU")
		_:
			print("[ComputeSelector] Unknown forced backend: %s" % force_backend)
			_select_backend()


func get_backend() -> Backend:
	"""Get the selected compute backend."""
	return selected_backend


func get_backend_name() -> String:
	"""Get human-readable backend name."""
	return Backend.keys()[selected_backend]


func is_gpu_available() -> bool:
	"""Check if GPU compute is available on this platform."""
	return selected_backend == Backend.GPU_COMPUTE


func get_platform_name() -> String:
	"""Get human-readable platform name."""
	return Platform.keys()[current_platform]
