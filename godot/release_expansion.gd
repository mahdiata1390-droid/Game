extends Node
## Release expansion pass: richer world landmarks, siege props, harbor, roads,
## environmental VFX and ambient lighting. Pure presentation layer.

var root: Node3D
var rng := RandomNumberGenerator.new()
var stone: StandardMaterial3D
var wood: StandardMaterial3D
var dark_wood: StandardMaterial3D
var metal: StandardMaterial3D
var dirt: StandardMaterial3D
var cloth: StandardMaterial3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_build")

func _build() -> void:
	var scene := get_tree().current_scene
	if scene == null or not (scene is Node3D): return
	root = Node3D.new()
	root.name = "ReleaseExpansion"
	scene.add_child(root)
	rng.seed = 913771
	stone = _mat(Color(0.34,0.35,0.34),0.86)
	wood = _mat(Color(0.28,0.13,0.055),0.9)
	dark_wood = _mat(Color(0.14,0.065,0.025),0.92)
	metal = _mat(Color(0.30,0.33,0.36),0.34,true)
	dirt = _mat(Color(0.24,0.18,0.12),1.0)
	cloth = _mat(Color(0.48,0.08,0.06),0.8)
	_build_road_network()
	_build_watchtowers()
	_build_siege_camp(Vector3(16,0,-2))
	_build_harbor(Vector3(-15,0,22))
	_build_market_square(Vector3(18,0,-17))
	_build_ambient_vfx()
	_build_fire_lights()

func _mat(c:Color, r:=0.8, m:=false) -> StandardMaterial3D:
	var x:=StandardMaterial3D.new()
	x.albedo_color=c
	x.roughness=r
	x.metallic=0.5 if m else 0.0
	return x

func _box(p:Node3D, s:Vector3, pos:Vector3, mat, rot:=Vector3.ZERO) -> MeshInstance3D:
	var n:=MeshInstance3D.new()
	var q:=BoxMesh.new()
	q.size=s
	n.mesh=q
	n.position=pos
	n.rotation_degrees=rot
	n.material_override=mat
	p.add_child(n)
	return n

func _cyl(p:Node3D, r:float, h:float, pos:Vector3, mat, sides:=10) -> MeshInstance3D:
	var n:=MeshInstance3D.new()
	var q:=CylinderMesh.new()
	q.top_radius=r
	q.bottom_radius=r*1.03
	q.height=h
	q.radial_segments=sides
	n.mesh=q
	n.position=pos
	n.material_override=mat
	p.add_child(n)
	return n

func _build_road_network() -> void:
	var roads:=Node3D.new()
	roads.name="TradeRoadNetwork"
	root.add_child(roads)
	for z in [-14.0,-4.0,6.0,16.0]:
		for x in range(-30,31,4):
			_box(roads,Vector3(3.6,0.035,1.5),Vector3(x,0.018,z),dirt)
	for x in [-20.0,-10.0,0.0,10.0,20.0]:
		for z in range(-25,26,4):
			_box(roads,Vector3(1.5,0.035,3.6),Vector3(x,0.02,z),dirt)
	for x in [-24.0,-8.0,8.0,24.0]:
		_build_road_marker(roads,Vector3(x,0.05,0))

func _build_road_marker(p:Node3D,pos:Vector3) -> void:
	_cyl(p,0.10,1.7,pos+Vector3(0,0.85,0),wood,7)
	_box(p,Vector3(0.8,0.55,0.10),pos+Vector3(0,1.3,0),cloth)

func _build_watchtowers() -> void:
	for pos in [Vector3(-27,0,-20),Vector3(27,0,-20),Vector3(-27,0,20),Vector3(27,0,20)]:
		var t:=Node3D.new()
		t.name="BorderWatchtower"
		t.position=pos
		root.add_child(t)
		_cyl(t,1.25,4.8,Vector3(0,2.4,0),stone,10)
		_box(t,Vector3(3.0,0.35,3.0),Vector3(0,4.8,0),wood)
		for a in range(4):
			var ang=TAU*float(a)/4.0
			_box(t,Vector3(0.5,0.7,0.7),Vector3(cos(ang)*1.1,5.25,sin(ang)*1.1),stone)
		_add_banner(t,Vector3(0,5.0,0),Color(0.12,0.20,0.42))

func _add_banner(p:Node3D,pos:Vector3,c:Color) -> void:
	_box(p,Vector3(0.08,2.3,0.08),pos+Vector3(0,1.0,0),dark_wood)
	_box(p,Vector3(0.95,1.35,0.05),pos+Vector3(0.47,0.55,0),_mat(c,0.85))

func _build_siege_camp(center:Vector3) -> void:
	var camp:=Node3D.new()
	camp.name="SiegeCamp"
	camp.position=center
	root.add_child(camp)
	for i in range(5):
		var a:=TAU*float(i)/5.0
		var p:=Vector3(cos(a)*5.0,0,sin(a)*5.0)
		_build_tent(camp,p,0.9+0.1*(i%2))
	for i in range(3):
		var p:=Vector3(-3.0+i*3.0,0,-1.0)
		_cyl(camp,0.12,3.2,p+Vector3(0,1.6,0),dark_wood,7)
		_box(camp,Vector3(0.18,2.0,0.18),p+Vector3(0.8,1.0,0),dark_wood,Vector3(0,0,-25))
	_box(camp,Vector3(5.2,0.55,0.65),Vector3(0,1.0,4.2),wood)
	for x in [-2.0,2.0]:
		_cyl(camp,0.65,0.35,Vector3(x,0.45,4.2),wood,12)
	for x in [-2.1,2.1]:
		_cyl(camp,0.12,2.5,Vector3(x,1.7,4.2),dark_wood,7)

func _build_tent(p:Node3D,pos:Vector3,s:float) -> void:
	_box(p,Vector3(2.8*s,0.08,2.2*s),pos+Vector3(0,0.04,0),dirt)
	_box(p,Vector3(2.5*s,1.5*s,0.08),pos+Vector3(0,0.75*s,-0.85*s),cloth,Vector3(-8,0,0))
	_box(p,Vector3(2.5*s,1.5*s,0.08),pos+Vector3(0,0.75*s,0.85*s),cloth,Vector3(8,0,0))
	_cyl(p,0.06,1.9*s,pos+Vector3(0,0.95*s,0),wood,6)

func _build_harbor(center:Vector3) -> void:
	var h:=Node3D.new()
	h.name="Harbor"
	h.position=center
	root.add_child(h)
	for i in range(7):
		_box(h,Vector3(3.0,0.18,0.45),Vector3(-9+i*3.0,0.1,0),wood)
	for i in range(6):
		_cyl(h,0.11,1.2,Vector3(-7.5+i*3.0,0.6,0.0),dark_wood,7)
	_build_boat(h,Vector3(0,0.2,3.2),1.0)
	_build_boat(h,Vector3(7,0.2,5.0),0.72)

func _build_boat(p:Node3D,pos:Vector3,s:float) -> void:
	var b:=Node3D.new()
	b.position=pos
	p.add_child(b)
	_box(b,Vector3(5.0*s,0.45,1.35*s),Vector3(0,0,0),wood)
	_box(b,Vector3(3.8*s,0.25,1.0*s),Vector3(0,0.28,0),dark_wood)
	_cyl(b,0.10,3.5*s,Vector3(0,1.8,0),wood,7)
	_box(b,Vector3(2.4*s,2.1*s,0.08),Vector3(0,2.0,0),_mat(Color(0.76,0.72,0.58),0.95))

func _build_market_square(center:Vector3) -> void:
	var m:=Node3D.new()
	m.name="GrandMarket"
	m.position=center
	root.add_child(m)
	_box(m,Vector3(15,0.06,12),Vector3(0,0.03,0),_mat(Color(0.34,0.29,0.22)))
	for i in range(8):
		var x:float=-5.5+(i%4)*3.7
		var z:float=-3.5+float(i/4)*7.0
		_box(m,Vector3(2.3,0.9,1.5),Vector3(x,0.45,z),wood)
		_box(m,Vector3(2.6,0.12,1.8),Vector3(x,1.55,z),_mat(Color(0.14+0.04*(i%3),0.25,0.34)))
	for x in [-6.0,6.0]:
		_cyl(m,0.12,3.4,Vector3(x,1.7,0),wood,7)
		_add_banner(m,Vector3(x,2.8,0),Color(0.55,0.32,0.08))

func _build_ambient_vfx() -> void:
	var embers:=CPUParticles3D.new()
	embers.name="AmbientEmbers"
	embers.amount=70
	embers.lifetime=3.0
	embers.position=Vector3(0,0.8,0)
	embers.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents=Vector3(28,1.2,28)
	embers.direction=Vector3(0,1,0)
	embers.spread=25.0
	embers.initial_velocity_min=0.2
	embers.initial_velocity_max=0.8
	embers.scale_amount_min=0.018
	embers.scale_amount_max=0.04
	embers.color=Color(1.0,0.32,0.06,0.55)
	root.add_child(embers)

func _build_fire_lights() -> void:
	for p in [Vector3(-12,0,8),Vector3(12,0,8),Vector3(-18,0,-12),Vector3(18,0,-12)]:
		var fire:=OmniLight3D.new()
		fire.position=p+Vector3(0,1.8,0)
		fire.light_color=Color(1.0,0.34,0.08)
		fire.light_energy=1.1
		fire.omni_range=5.5
		root.add_child(fire)
		var glow:=MeshInstance3D.new()
		var mesh:=SphereMesh.new()
		mesh.radius=0.18
		mesh.height=0.36
		glow.mesh=mesh
		glow.position=p+Vector3(0,1.25,0)
		glow.material_override=_mat(Color(1.0,0.20,0.03),0.35)
		root.add_child(glow)
