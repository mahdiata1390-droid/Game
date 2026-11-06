extends Node
## Release polish systems: dynamic atmosphere, day/night tint, weather accents,
## combat impact visuals and a lightweight world clock.

var root: Node3D
var time_of_day := 8.0
var weather_clock := 0.0
var weather_state := 0
var pulse_clock := 0.0
var last_battle := false
var env: Environment
var sun: DirectionalLight3D
var weather_particles: CPUParticles3D
var weather_label: Label
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    rng.seed = 77291
    call_deferred("_setup")

func _setup() -> void:
    var scene := get_tree().current_scene
    if scene == null: return
    root = Node3D.new()
    root.name = "ReleasePolish"
    scene.add_child(root)
    _find_lighting(scene)
    _build_weather()
    _build_clock_ui(scene)

func _find_lighting(scene: Node) -> void:
    for child in scene.get_children():
        if child is DirectionalLight3D:
            sun = child
        if child is WorldEnvironment:
            env = child.environment
    if env == null:
        env = Environment.new()
        var we := WorldEnvironment.new()
        we.environment = env
        scene.add_child(we)
    if sun == null:
        sun = DirectionalLight3D.new()
        scene.add_child(sun)
    sun.rotation_degrees = Vector3(-52,-28,0)

func _build_weather() -> void:
    weather_particles = CPUParticles3D.new()
    weather_particles.name = "WeatherParticles"
    weather_particles.amount = 180
    weather_particles.lifetime = 2.4
    weather_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    weather_particles.emission_box_extents = Vector3(34,6,34)
    weather_particles.position = Vector3(0,8,0)
    weather_particles.direction = Vector3(0,-1,0)
    weather_particles.spread = 7.0
    weather_particles.initial_velocity_min = 5.0
    weather_particles.initial_velocity_max = 8.0
    weather_particles.scale_amount_min = 0.018
    weather_particles.scale_amount_max = 0.035
    weather_particles.color = Color(0.72,0.80,0.92,0.38)
    weather_particles.emitting = false
    root.add_child(weather_particles)

func _build_clock_ui(scene: Node) -> void:
    var layer := CanvasLayer.new()
    layer.name = "ReleaseClockLayer"
    scene.add_child(layer)
    weather_label = Label.new()
    weather_label.position = Vector2(24,18)
    weather_label.add_theme_font_size_override("font_size",18)
    weather_label.add_theme_color_override("font_color",Color(0.92,0.86,0.68))
    weather_label.text = "DAY 1 • 08:00 • CLEAR"
    layer.add_child(weather_label)

func _process(delta: float) -> void:
    if root == null: return
    time_of_day = fmod(time_of_day + delta * 0.035, 24.0)
    weather_clock += delta
    pulse_clock += delta
    if weather_clock > 45.0:
        weather_clock = 0.0
        weather_state = rng.randi_range(0,2)
        weather_particles.emitting = weather_state == 1
    _update_atmosphere()
    _update_clock()
    _watch_battle()

func _update_atmosphere() -> void:
    var daylight := clamp(sin((time_of_day-6.0)/12.0*PI),0.08,1.0)
    if sun != null:
        sun.light_energy = 0.35 + daylight * 0.95
        sun.rotation_degrees.x = -25.0 - daylight * 42.0
    if env != null:
        env.ambient_light_energy = 0.35 + daylight * 0.55
        env.background_color = Color(0.025 + daylight*0.045,0.035 + daylight*0.055,0.07 + daylight*0.09)

func _update_clock() -> void:
    if weather_label == null: return
    var h := int(time_of_day)
    var m := int((time_of_day-float(h))*60.0)
    var w := ["CLEAR","RAIN","WIND"][weather_state]
    weather_label.text = "DAY 1 • %02d:%02d • %s" % [h,m,w]

func _watch_battle() -> void:
    var scene := get_tree().current_scene
    if scene == null: return
    var active = bool(scene.get("battle_in_progress"))
    if active and not last_battle:
        _spawn_battle_impact()
    last_battle = active

func _spawn_battle_impact() -> void:
    if root == null: return
    var burst := GPUParticles3D.new()
    burst.name = "BattleImpact"
    burst.amount = 28
    burst.one_shot = true
    burst.lifetime = 0.45
    burst.explosiveness = 0.9
    burst.direction = Vector3(0,1,0)
    burst.spread = 180.0
    burst.initial_velocity_min = 2.0
    burst.initial_velocity_max = 5.0
    burst.scale_amount_min = 0.025
    burst.scale_amount_max = 0.06
    burst.position = Vector3(0,1.0,0)
    root.add_child(burst)
    burst.emitting = true
