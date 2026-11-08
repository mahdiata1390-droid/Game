extends Node
## Release visual/content pass. Adds authored-feeling materials, landmarks, VFX,
## character detail and generated audio without touching campaign simulation state.

var root: Node3D
var rng := RandomNumberGenerator.new()
var mats: Dictionary = {}
var audio_players: Array[AudioStreamPlayer] = []
var built := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_build")

func _build() -> void:
    if built: return
    var scene := get_tree().current_scene
    if scene == null or not (scene is Node3D): return
    root = Node3D.new()
    root.name = "ReleaseContent"
    scene.add_child(root)
    rng.seed = 824713
    _build_materials()
    _build_castle(Vector3(0, 0, 12), "Northwatch")
    _build_city(Vector3(-8, 0, -7), "Stonebridge", 0)
    _build_city(Vector3(10, 0, -10), "Redmarket", 1)
    _build_farmland(Vector3(-18, 0, -2))
    _build_forest(Vector3(22, 0, 18), 42, 1.15)
    _build_forest(Vector3(-24, 0, 15), 36, 0.95)
    _build_particles()
    _build_audio()
    call_deferred("_decorate_existing_troops")
    built = true

func _build_materials() -> void:
    mats["stone"] = _texture_mat("res://assets/release/stone.svg", Color(0.72,0.72,0.70))
    mats["plaster"] = _texture_mat("res://assets/release/plaster.svg", Color(0.90,0.78,0.60))
    mats["timber"] = _texture_mat("res://assets/release/timber.svg", Color(0.80,0.70,0.55))
    mats["roof"] = _texture_mat("res://assets/release/roof.svg", Color(0.72,0.48,0.42))
    mats["wood"] = _mat(Color(0.25,0.12,0.055))
    mats["metal"] = _mat(Color(0.44,0.47,0.50), 0.35, true)
    mats["gold"] = _mat(Color(0.72,0.52,0.18), 0.28, true)
    mats["grass"] = _mat(Color(0.17,0.29,0.12))
    mats["water"] = _mat(Color(0.08,0.28,0.36), 0.12, false)

func _mat(color: Color, roughness := 0.82, metallic := false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = 0.45 if metallic else 0.0
    return m

func _texture_mat(path: String, tint: Color) -> StandardMaterial3D:
    var m := _mat(tint)
    # SVG source files are optional design references only; Android uses
    # native StandardMaterial colors here so headless/mobile rendering never
    # depends on an external SVG loader.
    return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat, rot := Vector3.ZERO) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    n.rotation_degrees = rot
    n.material_override = mat
    parent.add_child(n)
    return n

func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat, sides := 10) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius * 1.03
    mesh.height = height
    mesh.radial_segments = sides
    n.mesh = mesh
    n.position = pos
    n.material_override = mat
    parent.add_child(n)
    return n

func _sphere(parent: Node3D, radius: float, pos: Vector3, mat) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 12
    mesh.rings = 8
    n.mesh = mesh
    n.position = pos
    n.material_override = mat
    parent.add_child(n)
    return n

func _roof(parent: Node3D, pos: Vector3, size: Vector3, color_mat) -> void:
    _box(parent, Vector3(size.x, 0.22, size.z * 0.56), pos + Vector3(0, size.y * 0.55, -size.z * 0.20), color_mat, Vector3(0,0,-24))
    _box(parent, Vector3(size.x, 0.22, size.z * 0.56), pos + Vector3(0, size.y * 0.55, size.z * 0.20), color_mat, Vector3(0,0,24))
    _box(parent, Vector3(size.x * 0.90, 0.16, 0.22), pos + Vector3(0, size.y * 0.92, 0), mats["timber"])

func _build_castle(center: Vector3, title: String) -> void:
    var c := Node3D.new()
    c.name = "Castle_%s" % title
    c.position = center
    root.add_child(c)
    _box(c, Vector3(25,0.12,2.8), Vector3(0,-0.02,-11.5), mats["water"])
    _box(c, Vector3(6.2,0.28,3.4), Vector3(0,0.12,-10.0), mats["timber"])
    _box(c, Vector3(22,4.8,0.85), Vector3(0,2.4,-8.7), mats["stone"])
    _box(c, Vector3(22,4.8,0.85), Vector3(0,2.4,8.7), mats["stone"])
    _box(c, Vector3(0.85,4.8,17.5), Vector3(-10.6,2.4,0), mats["stone"])
    _box(c, Vector3(0.85,4.8,17.5), Vector3(10.6,2.4,0), mats["stone"])
    for side in [-1,1]:
        for i in range(9):
            var x := -9.0 + i * 2.25
            _box(c, Vector3(0.72,0.85,0.92), Vector3(x,5.2,side*8.7), mats["stone"])
    for side in [-1,1]:
        for i in range(7):
            var z := -6.8 + i * 2.25
            _box(c, Vector3(0.92,0.85,0.72), Vector3(side*10.6,5.2,z), mats["stone"])
    for p in [Vector3(-10.6,0,-8.7),Vector3(10.6,0,-8.7),Vector3(-10.6,0,8.7),Vector3(10.6,0,8.7)]:
        _build_castle_tower(c,p)
    _box(c, Vector3(6.4,5.8,2.0), Vector3(0,2.9,-9.2), mats["stone"])
    _box(c, Vector3(2.8,4.0,2.2), Vector3(0,2.0,-8.0), mats["wood"])
    _box(c, Vector3(3.2,0.28,2.5), Vector3(0,5.9,-9.2), mats["timber"])
    _box(c, Vector3(8.0,7.0,7.0), Vector3(0,3.5,1.0), mats["stone"])
    _roof(c, Vector3(0,7.1,1.0), Vector3(8.8,2.4,7.8), mats["roof"])
    for x in [-2.8,0,2.8]:
        for z in [-2.0,0.8,3.0]:
            _box(c, Vector3(0.38,0.65,0.12), Vector3(x,4.1,z), mats["metal"])
    for x in [-4.0,4.0]:
        _build_banner(c, Vector3(x,6.1,-10.1), Color(0.50 + rng.randf()*0.25,0.06,0.06))
        _build_torch(c, Vector3(x,3.0,-10.25))
    var label := Label3D.new()
    label.text = title
    label.position = Vector3(0,8.7,1)
    label.font_size = 64
    label.outline_size = 10
    c.add_child(label)

func _build_castle_tower(parent: Node3D, pos: Vector3) -> void:
    var t := Node3D.new()
    t.position = pos
    parent.add_child(t)
    _cyl(t,1.65,5.8,Vector3(0,2.9,0),mats["stone"],12)
    _cyl(t,1.95,0.35,Vector3(0,5.85,0),mats["timber"],12)
    for i in range(8):
        var a := TAU * float(i) / 8.0
        _box(t,Vector3(0.52,0.75,0.72),Vector3(cos(a)*1.48,6.25,sin(a)*1.48),mats["stone"])
    for y in [2.0,3.7]:
        _box(t,Vector3(0.16,0.75,0.10),Vector3(0,y,-1.62),mats["metal"])

func _build_banner(parent: Node3D, pos: Vector3, color: Color) -> void:
    _box(parent,Vector3(0.10,3.0,0.10),pos + Vector3(0,1.3,0),mats["wood"])
    var banner_mat := _mat(color)
    _box(parent,Vector3(1.35,1.9,0.06),pos + Vector3(0.62,0.55,0),banner_mat)
    _box(parent,Vector3(0.16,1.45,0.08),pos + Vector3(0.62,0.55,-0.06),mats["gold"])

func _build_torch(parent: Node3D, pos: Vector3) -> void:
    _box(parent,Vector3(0.14,1.2,0.14),pos + Vector3(0,0.6,0),mats["wood"])
    var flame := OmniLight3D.new()
    flame.light_color = Color(1.0,0.42,0.10)
    flame.light_energy = 1.8
    flame.omni_range = 5.5
    flame.position = pos + Vector3(0,1.25,0)
    parent.add_child(flame)
    _sphere(parent,0.22,pos + Vector3(0,1.35,0),_mat(Color(1.0,0.24,0.03),0.35))

func _build_city(center: Vector3, title: String, variant: int) -> void:
    var city := Node3D.new()
    city.name = "City_%s" % title
    city.position = center
    root.add_child(city)
    var wall_mat = mats["stone"] if variant == 0 else mats["plaster"]
    var roof_mat = mats["roof"] if variant == 0 else mats["timber"]
    _box(city,Vector3(20,0.08,18),Vector3(0,0.04,0),_mat(Color(0.30,0.25,0.19)))
    for i in range(6):
        var h := Node3D.new()
        h.position = Vector3(-7.5 + float(i%3)*7.5,0,-5.0 + float(i/3)*8.5)
        city.add_child(h)
        var w := 3.2 + float(i%2)*0.6
        var d := 3.0 + float((i+1)%2)*0.5
        _box(h,Vector3(w,2.5,d),Vector3(0,1.25,0),wall_mat)
        _roof(h,Vector3(0,2.55,0),Vector3(w+0.6,1.0,d+0.5),roof_mat)
        _box(h,Vector3(0.62,1.2,0.10),Vector3(0,0.6,-d*0.51),mats["wood"])
        for wx in [-0.9,0.9]:
            _box(h,Vector3(0.42,0.48,0.08),Vector3(wx,1.35,-d*0.52),mats["metal"])
        if i % 2 == 0:
            _box(h,Vector3(0.38,0.9,0.38),Vector3(w*0.28,2.9,0.35),mats["stone"])
    for i in range(4):
        var x := -6.0 + i*4.0
        _box(city,Vector3(2.8,0.9,1.4),Vector3(x,0.45,3.0),mats["timber"])
        _box(city,Vector3(3.0,0.12,1.7),Vector3(x,1.65,3.0),_mat(Color(0.50+0.08*(i%2),0.12,0.08)))
        _cyl(city,0.34,0.18,Vector3(x-1.0,0.25,3.75),mats["wood"],12)
        _cyl(city,0.34,0.18,Vector3(x+1.0,0.25,3.75),mats["wood"],12)
    _cyl(city,1.0,0.7,Vector3(0,0.35,0),mats["stone"],12)
    _cyl(city,0.66,0.72,Vector3(0,0.72,0),mats["water"],12)
    for x in [-8.5,8.5]:
        _box(city,Vector3(0.16,2.8,0.16),Vector3(x,1.4,0),mats["wood"])
        var light := OmniLight3D.new()
        light.position=Vector3(x,2.65,0)
        light.light_color=Color(1.0,0.55,0.22)
        light.light_energy=0.65
        light.omni_range=4.0
        city.add_child(light)
    var label := Label3D.new()
    label.text=title
    label.position=Vector3(0,4.3,0)
    label.font_size=52
    label.outline_size=8
    city.add_child(label)

func _build_farmland(center: Vector3) -> void:
    var farm := Node3D.new()
    farm.name="Farmland"
    farm.position=center
    root.add_child(farm)
    for row in range(8):
        for col in range(7):
            var x := -9.0 + col*2.4
            var z := -6.0 + row*1.7
            _box(farm,Vector3(1.8,0.05,1.0),Vector3(x,0.025,z),mats["grass"])
            if (row+col)%3==0:
                for k in range(3):
                    _cyl(farm,0.035,0.55,Vector3(x-0.45+k*0.45,0.3,z),mats["gold"],5)

func _build_forest(center: Vector3, count: int, scale: float) -> void:
    var forest := Node3D.new()
    forest.name="DetailedForest_%d_%d"%[int(center.x),int(center.z)]
    forest.position=center
    root.add_child(forest)
    for i in range(count):
        var s:=scale*rng.randf_range(0.75,1.35)
        var p:=Vector3(rng.randf_range(-12,12),0,rng.randf_range(-12,12))
        _cyl(forest,0.18*s,1.8*s,p+Vector3(0,0.9*s,0),mats["wood"],7)
        for j in range(3):
            _sphere(forest,0.65*s,p+Vector3(rng.randf_range(-0.35,0.35),1.8*s+j*0.48*s,rng.randf_range(-0.35,0.35)),_mat(Color(0.07+0.02*j,0.23+0.025*j,0.09)))

func _build_particles() -> void:
    var dust := CPUParticles3D.new()
    dust.name="DustMotes"
    dust.amount=120
    dust.lifetime=5.0
    dust.local_coords=false
    dust.position=Vector3(0,2,0)
    dust.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
    dust.emission_box_extents=Vector3(32,3,32)
    dust.direction=Vector3(0,1,0)
    dust.spread=180.0
    dust.initial_velocity_min=0.05
    dust.initial_velocity_max=0.22
    dust.scale_amount_min=0.015
    dust.scale_amount_max=0.035
    dust.color=Color(0.75,0.67,0.50,0.22)
    root.add_child(dust)

func _decorate_existing_troops() -> void:
    var scene := get_tree().current_scene
    if scene == null: return
    var troops = scene.get("troops")
    if not (troops is Array): return
    for data in troops:
        var node = data.get("node")
        if node is Node3D and is_instance_valid(node):
            _add_face_detail(node, int(rng.randi()%5))

func _add_face_detail(parent: Node3D, variant: int) -> void:
    var skin = _mat(Color(0.52+0.05*(variant%3),0.34+0.04*(variant%2),0.22+0.03*(variant%2)))
    var hair = _mat(Color(0.08+0.04*(variant%4),0.045+0.025*(variant%3),0.025))
    _sphere(parent,0.07,Vector3(-0.105,1.81,-0.265),hair)
    _sphere(parent,0.07,Vector3(0.105,1.81,-0.265),hair)
    _box(parent,Vector3(0.06,0.08,0.10),Vector3(0,1.74,-0.285),skin)
    if variant%2==0:
        _sphere(parent,0.16,Vector3(0,1.70,0.06),hair)

func _build_audio() -> void:
    _add_loop_music()
    _add_sfx_bus()

func _wav(samples: PackedByteArray, rate: int, loop := false) -> AudioStreamWAV:
    var wav:=AudioStreamWAV.new()
    wav.format=AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate=rate
    wav.stereo=false
    wav.data=samples
    if loop:
        wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
        wav.loop_end=int(samples.size()/2)
    return wav

func _pcm_tone(freq: float, seconds: float, volume: float, rate := 22050) -> PackedByteArray:
    var count:=int(seconds*rate)
    var data:=PackedByteArray()
    data.resize(count*2)
    for i in range(count):
        var t:=float(i)/rate
        var env: float = min(1.0,t*35.0)*min(1.0,(seconds-t)*12.0)
        var sample: float = sin(TAU*freq*t)*volume*env
        var v:=clamp(int(sample*32767.0),-32768,32767)
        data[i*2]=v&255
        data[i*2+1]=(v>>8)&255
    return data

func _add_sfx_bus() -> void:
    var player:=AudioStreamPlayer.new()
    player.name="CombatSFX"
    root.add_child(player)
    audio_players.append(player)
    player.stream=_wav(_pcm_tone(180,0.16,0.32),22050)
    player.volume_db=-14.0
    player.add_to_group("release_sfx")

func play_hit_sfx() -> void:
    for p in audio_players:
        if p.is_in_group("release_sfx"):
            p.play()
            return

func _add_loop_music() -> void:
    var rate:=11025
    var note_data:=PackedByteArray()
    var notes=[110.0,146.83,174.61,220.0,174.61,146.83,123.47,164.81]
    var per:=0.42
    for f in notes:
        note_data.append_array(_pcm_tone(f,per,0.08,rate))
    var player:=AudioStreamPlayer.new()
    player.name="OriginalMusic"
    player.stream=_wav(note_data,rate,true)
    player.volume_db=-20.0
    root.add_child(player)
    player.play()
