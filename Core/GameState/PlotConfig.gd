class_name PlotConfig
extends Resource

## PlotConfig - Configuration for a single plot in the grid
## Defines position, activity status, keyboard label, and biome assignment

@export var position: Vector2i
@export var is_active: bool = true
@export var keyboard_label: String = ""    # T/Y/U/0/9/8/7
@export var input_action: String = ""      # select_plot_t, select_plot_0, etc.
@export var biome_name: String = ""        # Market, BioticFlux, Forest


func _to_string() -> String:
	return "PlotConfig(%s, %s, label=%s, biome=%s)" % [position, "active" if is_active else "inactive", keyboard_label, biome_name]
