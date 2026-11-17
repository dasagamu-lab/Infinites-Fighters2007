extends CharacterBody2D
class_name Jugador

signal vida_cambiada(nueva_vida: int)

@export var player_id : int = 1
var HitSpark = preload("res://Assets/Escenas/HitSpark.tscn")
var EfectoChoque = preload("res://Assets/Codigos/ChoqueEfecto.gd")
var inputs := {}

# NODOS VISUALES Y COLISIONES
@onready var hurtbox = $Hurtbox
@onready var col_dano = $Col_Daño
@onready var ani = $AnimatedSprite2D
@onready var mirror = $AnimatedSprite2D
@onready var anim_player = $AnimationPlayer
@onready var pushbox = get_node_or_null("Pushbox")

enum EstadoFSM {
	NORMAL, AGACHADO, ATACANDO, BLOQUEANDO, DASH, HITSTUN, ESPECIAL, MUERTO,
	ESTOCADA_VELOZ, ANTIAEREO, COUNTER_POSE, COUNTER_IMPACTO, COUNTER_ATTACK, BLOQUEO_IMPACTO,
	CHOQUE, AGARRANDO, AGARRADO
}

# Fases del agarre: de INICIO a RECUPERACION son del que agarra; de SUJETADO a DERRIBADO, del agarrado.
enum FaseAgarre { NINGUNA, INICIO, ACTIVO, FALLO, SUJETANDO, RECUPERACION, SUJETADO, LANZADO, DERRIBADO }

# ESTADOS GLOBALES
var estado: EstadoFSM = EstadoFSM.NORMAL
var intMove : int = 0
var Can_Dash : int = 2
var id_hitstun_actual : int = 0
var tipo_ataque_actual : String = "debil"
var tiempo_impacto_bloqueo : float = 0.0
var tiempo_choque : float = 0.0
var polvo_choque : CPUParticles2D
var vida_maxima : int = 100
var fase_agarre : FaseAgarre = FaseAgarre.NINGUNA
var tiempo_agarre : float = 0.0
var pareja_agarre : Jugador = null
var direccion_agarre : int = 1
var daño_pendiente_agarre : int = 0
var posicion_sprite_base := Vector2.ZERO
var z_sprite_base : int = 0
static var hit_stops_activos : int = 0

# VELOCIDADES Y FÍSICAS (Compartidas)
var intVX : int = 170
var intVY : int = 480
var intVX_Dash : int = 300
var Jump_Height : int = 240
var frame_cancel_debil : int = 3 
var limite_izquierdo : float = 0.0
var limite_derecho : float = 400.0
var max_coyote_time : float = 0.2
var coyote_time : float = 0.0
var Time_Actual_Dupli : float = 0
var Time_Dupli : float = 0.05
var Time_Life_Dupli : float = 0.2
var sprite_pos_atacando = Vector2.ZERO
var frame_cancel_especial : int = 3 

# ESTADÍSTICAS GLOBALES (Configurables desde el Inspector)
@export var vida : int = 100
@export var fuerza_golpe : int = 120
@export var duración_hitstun : float = 0.35

@export_category("Daño de ataques")
@export var daño_ataque_debil : int = 10
@export var daño_ataque_medio : int = 20
@export var daño_especial : int = 30
@export var daño_counter : int = 40

@export_category("Bloqueo")
@export var retroceso_bloqueo : float = 45.0
@export var frenado_bloqueo : float = 1600.0
@export var duracion_impacto_bloqueo : float = 0.12
@export var hitstop_bloqueo : float = 0.06
@export var intensidad_camara_bloqueo : float = 0.7

@export_category("Choque de ataques")
@export var retroceso_choque : float = 190.0
@export var frenado_choque : float = 640.0
@export var duracion_choque : float = 0.34
@export var hitstop_choque : float = 0.12
@export var intensidad_camara_choque : float = 4.0
@export var duracion_camara_choque : float = 0.3

@export_category("Agarre")
@export var daño_agarre : int = 15
@export var alcance_agarre : float = 32.0
@export var inicio_agarre : float = 0.08
@export var ventana_agarre : float = 0.06
@export var recuperacion_fallo_agarre : float = 0.4
@export var duracion_sujecion : float = 0.3
## Tiempo que tiene el agarrado para soltarse pulsando su tecla de agarre (0 = sin escape).
@export var ventana_escape_agarre : float = 0.2
@export var fuerza_lanzamiento : Vector2 = Vector2(180, 215)
@export var recuperacion_agarre : float = 0.25
@export var tiempo_derribado : float = 0.45

func _ready():
	add_to_group("jugadores")
	# La vida del Inspector es la vida máxima: la usan la barra y el reinicio de ronda.
	vida_maxima = vida
	posicion_sprite_base = ani.position
	z_sprite_base = ani.z_index
	desactivar_hitboxes()

	if player_id == 1:
		hurtbox.collision_layer = 2
		hurtbox.collision_mask = 16
		col_dano.collision_layer = 8
		col_dano.collision_mask = 0
	else:
		hurtbox.collision_layer = 4
		hurtbox.collision_mask = 8
		col_dano.collision_layer = 16
		col_dano.collision_mask = 0
		
	if player_id == 1:
		inputs = {
			"ataque_debil": "Ataque_1", "ataque_medio": "Ataque_2", "bloqueo": "Bloqueo",
			"especial": "Especial", "abajo": "Abajo", "derecha": "Derecha",
			"izquierda": "Izquierda", "dash": "Dash", "salto": "Saltar", "counter": "Counter",
			"agarre": "Agarre"
		}
	else:
		inputs = {
			"ataque_debil": "ataque_debil_P2", "ataque_medio": "ataque_medio_P2",
			"bloqueo": "Bloqueo_P2", "especial": "Especial_P2", "abajo": "Abajo_P2",
			"derecha": "Derecha_P2", "izquierda": "Izquierda_P2", "dash": "Dash_P2",
			"salto": "Salto_P2", "counter": "Counter_P2", "agarre": "Agarre_P2"
		}
	# Si el editor sobrescribe project.godot y se pierde la tecla de agarre, se crea aquí.
	asegurar_accion(inputs["agarre"], KEY_R if player_id == 1 else KEY_U)
	
	if is_instance_valid(anim_player):
		anim_player.animation_finished.connect(_on_animation_player_finished)

	crear_polvo_choque()

func desactivar_hitboxes():
	if not is_instance_valid(col_dano):
		return
	for child in col_dano.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)

func crear_hit_spark(posicion: Vector2, color: Color = Color(1, 1, 0.6, 1.0), tamaño: float = 5.0):
	var spark = HitSpark.instantiate()
	spark.global_position = posicion
	spark.color = color
	spark.radio = tamaño
	spark.z_index = 20
	get_tree().current_scene.add_child(spark)

func configurar_ataque(tipo: String) -> void:
	tipo_ataque_actual = tipo

func iniciar_ataque(nombre_animacion: String, tipo: String, velocidad: float = 1.0) -> void:
	estado = EstadoFSM.ATACANDO
	configurar_ataque(tipo)
	desactivar_hitboxes()
	ani.animation = nombre_animacion
	ani.stop()
	anim_player.play(nombre_animacion, -1, velocidad)

func puede_iniciar_ataque() -> bool:
	return is_on_floor() and estado != EstadoFSM.BLOQUEANDO and estado != EstadoFSM.BLOQUEO_IMPACTO and estado != EstadoFSM.ATACANDO

func puede_cancelar_ataque_debil(nombre_ataque_debil: String) -> bool:
	return estado == EstadoFSM.ATACANDO and ani.animation == nombre_ataque_debil and ani.frame >= frame_cancel_debil

# Se revisa en cada frame de física: así, mantener el botón bloquea apenas termina
# un hitstun, un ataque o un salto, sin esperar a que llegue otra tecla.
func procesar_entrada_bloqueo() -> void:
	if Input.is_action_pressed(inputs["bloqueo"]):
		if is_on_floor() and (estado == EstadoFSM.NORMAL or estado == EstadoFSM.AGACHADO):
			estado = EstadoFSM.BLOQUEANDO
			iniciar_animacion_bloqueo()
	elif estado == EstadoFSM.BLOQUEANDO:
		estado = EstadoFSM.NORMAL

func procesar_postura() -> void:
	if Input.is_action_pressed(inputs["abajo"]) and is_on_floor() and estado == EstadoFSM.NORMAL:
		estado = EstadoFSM.AGACHADO
	elif Input.is_action_just_released(inputs["abajo"]) and is_on_floor() and estado == EstadoFSM.AGACHADO:
		estado = EstadoFSM.NORMAL

func actualizar_direccion_entrada() -> void:
	# En DASH tampoco: el dash mantiene la dirección con la que salió.
	if estado == EstadoFSM.BLOQUEANDO or estado == EstadoFSM.ATACANDO or estado == EstadoFSM.ESPECIAL or estado == EstadoFSM.HITSTUN or estado == EstadoFSM.DASH:
		intMove = 0
		return
	if Input.is_action_pressed(inputs["derecha"]):
		intMove = 1
	elif Input.is_action_pressed(inputs["izquierda"]):
		intMove = -1
	else:
		intMove = 0

func intentar_iniciar_dash() -> bool:
	if not Input.is_action_just_pressed(inputs["dash"]) or Can_Dash <= 0:
		return false
	if estado != EstadoFSM.NORMAL and estado != EstadoFSM.AGACHADO:
		return false
	desactivar_hitboxes()
	anim_player.stop()
	estado = EstadoFSM.DASH
	Can_Dash -= 1
	return true

func procesar_hitstun(delta: float) -> bool:
	if estado != EstadoFSM.HITSTUN:
		return false
	velocity.x = move_toward(velocity.x, 0, 800 * delta)
	if not is_on_floor():
		velocity.y += intVY * delta
	move_and_slide()
	procesar_pushbox()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)
	return true

# El derrotado sigue cayendo hasta el suelo (si muere en el aire no se queda flotando).
func procesar_muerte(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 800 * delta)
	if is_on_floor():
		velocity.y = 0
	else:
		velocity.y += intVY * delta
	move_and_slide()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)

func procesar_movimiento_comun(delta: float) -> void:
	if is_on_floor():
		Can_Dash = 1

	match estado:
		EstadoFSM.NORMAL:
			if is_on_floor():
				coyote_time = max_coyote_time
				velocity.y = 0
			else:
				coyote_time -= delta
				velocity.y += intVY * delta
			velocity.x = intVX * intMove if intMove != 0 else 0
			if Input.is_action_just_pressed(inputs["salto"]) and (is_on_floor() or (coyote_time > 0 and velocity.y > 0.01)):
				velocity.y = -Jump_Height
			if Input.is_action_just_released(inputs["salto"]) and velocity.y < 0:
				velocity.y *= 0.5
		EstadoFSM.AGACHADO, EstadoFSM.ATACANDO, EstadoFSM.ESPECIAL:
			velocity = Vector2.ZERO
		EstadoFSM.BLOQUEANDO:
			velocity.x = move_toward(velocity.x, 0, frenado_bloqueo * delta)
			velocity.y = 0
		EstadoFSM.DASH:
			Time_Actual_Dupli += delta
			velocity.y = 0
			var direccion = sign(mirror.scale.x)
			velocity.x = intVX_Dash * (direccion if direccion != 0 else 1)
			if Time_Actual_Dupli >= Time_Dupli:
				Time_Actual_Dupli = 0
				crear_duplicado()

	_animaciones()
	move_and_slide()
	procesar_pushbox()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)
	actualizar_animacion_comun()

func actualizar_animacion_comun() -> void:
	match estado:
		EstadoFSM.NORMAL:
			if is_on_floor():
				if velocity.x == 0:
					ani.play("Idle", 0.8)
				else:
					ani.play("Run", 1.1)
			else:
				if velocity.y < 0:
					ani.play("Jump")	
				else:
					ani.play("Fall")
		EstadoFSM.AGACHADO:
			ani.play("Fase1_Agacharse")
		EstadoFSM.DASH:
			if is_on_floor():
				ani.play(obtener_animacion_dash(), 2.5)
			else:
				ani.play(obtener_animacion_dash_aire())
		EstadoFSM.BLOQUEANDO:
			mantener_animacion_bloqueo()

func obtener_animacion_dash() -> String:
	return "Dash"

func obtener_animacion_dash_aire() -> String:
	return "Dash_Aire"

func obtener_color_duplicado_dash() -> Color:
	return Color(0.3, 0.5, 1.0, 0.5)

func crear_duplicado() -> void:
	var duplicado = Sprite2D.new()
	duplicado.texture = ani.sprite_frames.get_frame_texture(ani.animation, ani.frame)
	duplicado.global_position = ani.global_position
	duplicado.scale = ani.scale.abs()
	duplicado.flip_h = mirror.scale.x < 0
	duplicado.z_index = z_index - 1
	duplicado.modulate = obtener_color_duplicado_dash()
	get_parent().add_child(duplicado)
	var timer = get_tree().create_timer(Time_Life_Dupli, false)
	timer.timeout.connect(func(): if is_instance_valid(duplicado): duplicado.queue_free())

func procesar_fin_animacion_sprite(nombre_animacion: String) -> bool:
	if nombre_animacion == obtener_animacion_dash() or nombre_animacion == obtener_animacion_dash_aire():
		estado = EstadoFSM.NORMAL
		return true
	return false

func obtener_daño_actual() -> int:
	match tipo_ataque_actual:
		"medio": return daño_ataque_medio
		"especial": return daño_especial
		"counter": return daño_counter
		_: return daño_ataque_debil

# Ganchos para los combos con continuación (como el Carmesí de Lum): el atacante puede
# alargar el hitstun de su golpe y enterarse de cuándo entró. Por defecto no cambian nada.
func obtener_hitstun_actual(por_defecto: float) -> float:
	return por_defecto

func al_conectar_golpe(_victima: Node2D) -> void:
	pass

func obtener_animacion_bloqueo() -> String:
	if ani.sprite_frames.has_animation("Bloqueo"):
		return "Bloqueo"
	return "Bloqueo_P2"

func iniciar_animacion_bloqueo() -> void:
	ani.play(obtener_animacion_bloqueo())

func mantener_animacion_bloqueo() -> void:
	var animacion = obtener_animacion_bloqueo()
	if ani.animation != animacion:
		ani.play(animacion)

func procesar_impacto_bloqueo(delta: float) -> bool:
	if estado != EstadoFSM.BLOQUEO_IMPACTO:
		return false

	tiempo_impacto_bloqueo -= delta
	velocity.x = move_toward(velocity.x, 0, frenado_bloqueo * delta)
	velocity.y = 0
	move_and_slide()
	procesar_pushbox()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)
	mantener_animacion_bloqueo()

	if tiempo_impacto_bloqueo <= 0:
		estado = EstadoFSM.BLOQUEANDO if Input.is_action_pressed(inputs["bloqueo"]) else EstadoFSM.NORMAL
		if estado == EstadoFSM.BLOQUEANDO:
			iniciar_animacion_bloqueo()
	return true

func reaccionar_bloqueo(area: Area2D) -> void:
	if estado != EstadoFSM.BLOQUEANDO and estado != EstadoFSM.BLOQUEO_IMPACTO:
		return

	var direccion = 1 if area.global_position.x < global_position.x else -1
	estado = EstadoFSM.BLOQUEO_IMPACTO
	tiempo_impacto_bloqueo = duracion_impacto_bloqueo
	velocity.x = direccion * retroceso_bloqueo
	velocity.y = 0
	aplicar_hit_stop(hitstop_bloqueo, 0.08)
	sacudir_camara(intensidad_camara_bloqueo, hitstop_bloqueo)
	
	# Colocar el spark de bloqueo justo en la zona donde la hitbox contacta con la hurtbox
	crear_hit_spark(calcular_punto_contacto(area), Color(0.5, 0.8, 1.0, 1.0), 4.5)
	mantener_animacion_bloqueo()

	var tween = create_tween()
	ani.modulate = Color(1.6, 1.6, 2.0, 1.0)
	tween.tween_property(ani, "modulate", Color.WHITE, duracion_impacto_bloqueo)

func aplicar_hit_stop(duracion: float = 0.20, escala: float = 0.06):
	hit_stops_activos += 1
	Engine.time_scale = min(Engine.time_scale, escala)
	var timer = get_tree().create_timer(duracion, true, false, true)
	timer.timeout.connect(func():
		hit_stops_activos -= 1
		if hit_stops_activos <= 0:
			hit_stops_activos = 0
			Engine.time_scale = 1.0
	)

# ==============================================================================
# CHOQUE DE ATAQUES (parry): dos golpes activos que se tocan se anulan.
# Nadie recibe daño; ambos salen despedidos hacia atrás levantando polvo.
# ==============================================================================
func obtener_rival() -> Jugador:
	for nodo in get_tree().get_nodes_in_group("jugadores"):
		if nodo != self and nodo is Jugador:
			return nodo
	return null

# Solo chocan los golpes cuerpo a cuerpo (el proyectil de Lum no cuenta).
func puede_chocar() -> bool:
	return estado == EstadoFSM.ATACANDO or estado == EstadoFSM.ESTOCADA_VELOZ or estado == EstadoFSM.ANTIAEREO

# Rectángulos globales de las formas activas de un Area2D (hitbox, hurtbox o proyectil).
func obtener_rects_area(area: Area2D) -> Array:
	var zonas := []
	if not is_instance_valid(area):
		return zonas
	for child in area.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape is RectangleShape2D:
			var tam: Vector2 = child.shape.size * child.global_scale.abs()
			zonas.append(Rect2(child.global_position - tam * 0.5, tam))
	return zonas

func obtener_hitboxes_activas() -> Array:
	return obtener_rects_area(col_dano)

# Centro de la zona donde el golpe toca mi hurtbox (si no se puede medir, el punto medio).
func calcular_punto_contacto(area: Area2D) -> Vector2:
	var mias = obtener_rects_area(hurtbox)
	for zona in obtener_rects_area(area):
		for propia in mias:
			if zona.intersects(propia, true):
				return zona.intersection(propia).get_center()
	return (area.global_position + hurtbox.global_position) * 0.5

# Devuelve el centro de la zona donde se tocan los dos golpes, o null si no se tocan.
func buscar_choque_con(rival: Jugador):
	if rival == null or not puede_chocar() or not rival.puede_chocar():
		return null
	for mia in obtener_hitboxes_activas():
		for suya in rival.obtener_hitboxes_activas():
			if mia.intersects(suya):
				return mia.intersection(suya).get_center()
	return null

func comprobar_choque() -> bool:
	var rival = obtener_rival()
	var punto = buscar_choque_con(rival)
	if punto == null:
		return false
	resolver_choque(rival, punto)
	return true

func resolver_choque(rival: Jugador, punto: Vector2) -> void:
	var x_rival = rival.global_position.x
	rival.entrar_en_choque(global_position.x)
	entrar_en_choque(x_rival)
	crear_efecto_choque(punto)
	aplicar_hit_stop(hitstop_choque, 0.05)
	sacudir_camara(intensidad_camara_choque, duracion_camara_choque)

func entrar_en_choque(x_rival: float) -> void:
	estado = EstadoFSM.CHOQUE
	id_hitstun_actual += 1
	intMove = 0
	desactivar_hitboxes()
	if is_instance_valid(anim_player):
		anim_player.call_deferred("stop")
	tiempo_choque = duracion_choque

	# Siempre hacia atrás, alejándose del rival.
	var direccion = sign(global_position.x - x_rival)
	if direccion == 0:
		direccion = -1.0 if mirror.scale.x >= 0 else 1.0
	velocity = Vector2(direccion * retroceso_choque, 0)

	# Si dibujas una animación llamada "Choque" se usa sola; si no, "Hit".
	if ani.sprite_frames:
		if ani.sprite_frames.has_animation("Choque"):
			ani.play("Choque")
		elif ani.sprite_frames.has_animation("Hit"):
			ani.play("Hit")
	var tween = create_tween()
	ani.modulate = Color(2.0, 2.0, 2.0, 1.0)
	tween.tween_property(ani, "modulate", Color.WHITE, 0.2)
	levantar_polvo(direccion)

func procesar_choque(delta: float) -> bool:
	if estado != EstadoFSM.CHOQUE:
		return false

	tiempo_choque -= delta
	velocity.x = move_toward(velocity.x, 0, frenado_choque * delta)
	if is_on_floor():
		velocity.y = 0
	else:
		velocity.y += intVY * delta
	move_and_slide()
	procesar_pushbox()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)

	if tiempo_choque <= 0:
		estado = EstadoFSM.NORMAL
		velocity.x = 0
		ani.play("Idle")
	return true

func crear_efecto_choque(punto: Vector2) -> void:
	var efecto = EfectoChoque.new()
	efecto.global_position = punto.round()
	efecto.z_index = 25
	get_tree().current_scene.add_child(efecto)

func obtener_altura_pies() -> float:
	var cuerpo = get_node_or_null("Colision")
	if cuerpo is CollisionShape2D and cuerpo.shape is RectangleShape2D:
		return cuerpo.position.y + cuerpo.shape.size.y * 0.5 - 1.0
	return 13.0

func crear_polvo_choque() -> void:
	polvo_choque = CPUParticles2D.new()
	polvo_choque.name = "PolvoChoque"
	polvo_choque.emitting = false
	polvo_choque.one_shot = true
	polvo_choque.amount = 34
	polvo_choque.lifetime = 0.55
	polvo_choque.explosiveness = 0.35
	polvo_choque.lifetime_randomness = 0.35
	# Las partículas se quedan donde nacen: el personaje se aleja y deja el rastro.
	polvo_choque.local_coords = false
	polvo_choque.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	polvo_choque.emission_rect_extents = Vector2(8, 1)
	polvo_choque.spread = 32.0
	polvo_choque.gravity = Vector2(0, 70)
	polvo_choque.initial_velocity_min = 22.0
	polvo_choque.initial_velocity_max = 65.0
	polvo_choque.damping_min = 50.0
	polvo_choque.damping_max = 90.0
	polvo_choque.scale_amount_min = 1.0
	polvo_choque.scale_amount_max = 3.0
	# Los granos grandes se encogen mientras se apagan.
	var curva_tam = Curve.new()
	curva_tam.add_point(Vector2(0.0, 1.0))
	curva_tam.add_point(Vector2(1.0, 0.45))
	polvo_choque.scale_amount_curve = curva_tam
	var degradado = Gradient.new()
	degradado.set_color(0, Color(0.93, 0.89, 0.80, 0.95))
	degradado.set_color(1, Color(0.70, 0.64, 0.56, 0.0))
	degradado.add_point(0.45, Color(0.82, 0.76, 0.66, 0.75))
	polvo_choque.color_ramp = degradado
	polvo_choque.position = Vector2(0, obtener_altura_pies())
	polvo_choque.z_index = 1
	add_child(polvo_choque)

func levantar_polvo(direccion: float) -> void:
	if not is_instance_valid(polvo_choque) or not is_on_floor():
		return
	# El polvo sale de los pies y se arrastra hacia atrás junto con el personaje.
	polvo_choque.direction = Vector2(direccion, -0.45).normalized()
	polvo_choque.restart()

# ==============================================================================
# AGARRE: agarrar al rival y arrojarlo. Le gana al bloqueo y a la pose del counter;
# un golpe le gana al agarre. Mientras lo sujeta, a ninguno de los dos le pueden pegar.
# ==============================================================================
func asegurar_accion(accion: String, tecla: Key) -> void:
	if InputMap.has_action(accion):
		return
	InputMap.add_action(accion)
	var evento = InputEventKey.new()
	evento.physical_keycode = tecla
	InputMap.action_add_event(accion, evento)

func intentar_iniciar_agarre() -> bool:
	if not Input.is_action_just_pressed(inputs["agarre"]) or not is_on_floor():
		return false
	if estado != EstadoFSM.NORMAL and estado != EstadoFSM.AGACHADO and estado != EstadoFSM.BLOQUEANDO and estado != EstadoFSM.DASH:
		return false
	iniciar_agarre()
	return true

func iniciar_agarre() -> void:
	estado = EstadoFSM.AGARRANDO
	fase_agarre = FaseAgarre.INICIO
	tiempo_agarre = 0.0
	pareja_agarre = null
	intMove = 0
	velocity = Vector2.ZERO
	desactivar_hitboxes()
	if is_instance_valid(anim_player):
		anim_player.stop()
	# Se gira hacia el rival: el agarre no depende de hacia dónde venía caminando.
	var rival = obtener_rival()
	if rival != null and rival.global_position.x != global_position.x:
		mirar_hacia(1 if rival.global_position.x > global_position.x else -1)
	direccion_agarre = 1 if mirror.scale.x >= 0 else -1
	# Mientras agarra, su sprite va delante del rival para que se vea la mano.
	ani.z_index = z_sprite_base + 1
	mostrar_animacion_agarre("Agarre")

# Solo se agarra a quien está en el suelo y fuera de hitstun, del impacto del bloqueo
# y de un choque: así un golpe seguido de agarre no es inevitable.
func puede_ser_agarrado() -> bool:
	if not is_on_floor():
		return false
	match estado:
		EstadoFSM.NORMAL, EstadoFSM.AGACHADO, EstadoFSM.BLOQUEANDO, EstadoFSM.DASH, EstadoFSM.ATACANDO, EstadoFSM.ESPECIAL, EstadoFSM.ESTOCADA_VELOZ, EstadoFSM.COUNTER_POSE:
			return true
		EstadoFSM.AGARRANDO:
			return fase_agarre == FaseAgarre.FALLO
	return false

func esta_intentando_agarrar() -> bool:
	return estado == EstadoFSM.AGARRANDO and (fase_agarre == FaseAgarre.INICIO or fase_agarre == FaseAgarre.ACTIVO)

func en_alcance_de_agarre(otro: Jugador) -> bool:
	var distancia = (otro.global_position.x - global_position.x) * direccion_agarre
	return distancia >= 0.0 and distancia <= alcance_agarre and abs(otro.global_position.y - global_position.y) <= 16.0

func es_invulnerable_por_agarre() -> bool:
	return estado == EstadoFSM.AGARRADO or (estado == EstadoFSM.AGARRANDO and fase_agarre == FaseAgarre.SUJETANDO)

func procesar_agarre(delta: float) -> bool:
	if estado == EstadoFSM.AGARRANDO:
		procesar_agarrando(delta)
		return true
	if estado == EstadoFSM.AGARRADO:
		procesar_agarrado(delta)
		return true
	return false

func procesar_agarrando(delta: float) -> void:
	tiempo_agarre += delta
	match fase_agarre:
		FaseAgarre.INICIO:
			if tiempo_agarre >= inicio_agarre:
				fase_agarre = FaseAgarre.ACTIVO
				tiempo_agarre = 0.0
		FaseAgarre.ACTIVO:
			var rival = obtener_rival()
			var al_alcance = rival != null and en_alcance_de_agarre(rival)
			if al_alcance and rival.esta_intentando_agarrar():
				# Los dos agarraron a la vez: se sueltan.
				escapar_agarre(rival)
				return
			if al_alcance and rival.puede_ser_agarrado():
				conectar_agarre(rival)
			elif tiempo_agarre >= ventana_agarre:
				fase_agarre = FaseAgarre.FALLO
				tiempo_agarre = 0.0
				# Con una animación "Agarre" dibujada, se queda con la mano estirada.
				if ani.animation == "Agarre":
					ani.pause()
		FaseAgarre.FALLO:
			if tiempo_agarre >= recuperacion_fallo_agarre:
				terminar_agarre()
				return
		FaseAgarre.SUJETANDO:
			if tiempo_agarre >= duracion_sujecion:
				lanzar_agarrado()
			else:
				sujetar(pareja_agarre)
		FaseAgarre.RECUPERACION:
			if tiempo_agarre >= recuperacion_agarre:
				terminar_agarre()
				return
	velocity = Vector2.ZERO
	move_and_slide()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)

func conectar_agarre(victima: Jugador) -> void:
	fase_agarre = FaseAgarre.SUJETANDO
	tiempo_agarre = 0.0
	pareja_agarre = victima
	mostrar_animacion_agarre("Agarre_Sujeta")
	victima.ser_agarrado(self)
	sujetar(victima)
	aplicar_hit_stop(0.06, 0.1)
	sacudir_camara(1.2, 0.1)

func ser_agarrado(agarrador: Jugador) -> void:
	estado = EstadoFSM.AGARRADO
	fase_agarre = FaseAgarre.SUJETADO
	tiempo_agarre = 0.0
	pareja_agarre = agarrador
	id_hitstun_actual += 1
	intMove = 0
	velocity = Vector2.ZERO
	desactivar_hitboxes()
	if is_instance_valid(anim_player):
		anim_player.call_deferred("stop")
	mirar_hacia(-agarrador.direccion_agarre)
	if ani.sprite_frames.has_animation("Agarrado"):
		ani.play("Agarrado")
	elif ani.sprite_frames.has_animation("Hit"):
		ani.play("Hit")

func sujetar(victima: Jugador) -> void:
	if not is_instance_valid(victima) or victima.estado != EstadoFSM.AGARRADO:
		return
	var x = clamp(global_position.x + direccion_agarre * 20.0, victima.limite_izquierdo, victima.limite_derecho)
	# Lo levanta poco a poco del suelo para que se note que lo tiene sujeto.
	var alzado = 4.0 * clamp(tiempo_agarre / (duracion_sujecion * 0.5), 0.0, 1.0)
	victima.global_position = Vector2(x, global_position.y - alzado)

func lanzar_agarrado() -> void:
	fase_agarre = FaseAgarre.RECUPERACION
	tiempo_agarre = 0.0
	mostrar_animacion_agarre("Agarre_Lanza")
	if is_instance_valid(pareja_agarre) and pareja_agarre.estado == EstadoFSM.AGARRADO:
		pareja_agarre.ser_lanzado(direccion_agarre, fuerza_lanzamiento, daño_agarre)
	sacudir_camara(1.5, 0.12)

func ser_lanzado(direccion: int, fuerza: Vector2, daño: int) -> void:
	fase_agarre = FaseAgarre.LANZADO
	tiempo_agarre = 0.0
	direccion_agarre = direccion
	daño_pendiente_agarre = daño
	velocity = Vector2(direccion * fuerza.x, -fuerza.y)
	if ani.sprite_frames.has_animation("Lanzado"):
		ani.play("Lanzado")

# Derribo sin agarre (por ejemplo, el remate de un combo): sale volando, cae y se levanta
# con las mismas fases y animaciones que el lanzamiento del agarre.
func ser_derribado(direccion: int, fuerza: Vector2) -> void:
	if estado == EstadoFSM.MUERTO:
		return
	limpiar_agarre()
	desactivar_hitboxes()
	if is_instance_valid(anim_player):
		anim_player.call_deferred("stop")
	estado = EstadoFSM.AGARRADO
	id_hitstun_actual += 1
	intMove = 0
	mirar_hacia(-direccion)
	ser_lanzado(direccion, fuerza, 0)

func procesar_agarrado(delta: float) -> void:
	tiempo_agarre += delta
	match fase_agarre:
		FaseAgarre.SUJETADO:
			var agarrador: Jugador = pareja_agarre
			if not is_instance_valid(agarrador) or agarrador.estado != EstadoFSM.AGARRANDO or agarrador.pareja_agarre != self:
				# Quien lo sujetaba ya no lo hace: queda libre.
				terminar_agarre()
			elif tiempo_agarre <= agarrador.ventana_escape_agarre and Input.is_action_just_pressed(inputs["agarre"]):
				agarrador.escapar_agarre(self)
		FaseAgarre.LANZADO:
			# Cae con el doble de gravedad que un salto: el lanzamiento es rápido y seco.
			velocity.y += intVY * 2.0 * delta
			move_and_slide()
			global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)
			if (tiempo_agarre > 0.1 and is_on_floor()) or tiempo_agarre > 1.5:
				aterrizar_lanzado()
		FaseAgarre.DERRIBADO:
			velocity.x = move_toward(velocity.x, 0, 800 * delta)
			velocity.y = 0.0 if is_on_floor() else velocity.y + intVY * delta
			move_and_slide()
			procesar_pushbox()
			global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)
			# En el último tramo se levanta, si tiene la animación dibujada.
			var levantarse = duracion_animacion("Levantarse")
			if levantarse > 0.0 and ani.animation != "Levantarse" and tiempo_agarre >= tiempo_derribado - levantarse:
				ani.play("Levantarse")
			if tiempo_agarre >= tiempo_derribado:
				terminar_agarre()

func aterrizar_lanzado() -> void:
	fase_agarre = FaseAgarre.DERRIBADO
	tiempo_agarre = 0.0
	velocity = Vector2(velocity.x * 0.3, 0.0)
	mostrar_pose_derribado()
	levantar_polvo(direccion_agarre)
	crear_hit_spark(global_position + Vector2(0, 8), Color(1, 1, 0.5, 1.0), 6.0)
	aplicar_hit_stop(0.08, 0.06)
	sacudir_camara(3.0, 0.22)
	vida = maxi(vida - daño_pendiente_agarre, 0)
	daño_pendiente_agarre = 0
	if vida <= 0:
		# Ya está tirado en el suelo: no repite la caída desde de pie.
		morir(false)
	vida_cambiada.emit(vida)

func terminar_agarre() -> void:
	limpiar_agarre()
	estado = EstadoFSM.NORMAL
	ani.play("Idle")

func limpiar_agarre() -> void:
	fase_agarre = FaseAgarre.NINGUNA
	tiempo_agarre = 0.0
	pareja_agarre = null
	daño_pendiente_agarre = 0
	ani.rotation = 0.0
	ani.position = posicion_sprite_base
	ani.z_index = z_sprite_base

# Escape: los dos se sueltan sin daño y salen despedidos como en un choque.
func escapar_agarre(otro: Jugador) -> void:
	var punto = (global_position + otro.global_position) * 0.5 + Vector2(0, -4)
	var x_otro = otro.global_position.x
	otro.limpiar_agarre()
	limpiar_agarre()
	otro.entrar_en_choque(global_position.x)
	entrar_en_choque(x_otro)
	crear_hit_spark(punto, Color(0.85, 0.95, 1.0, 1.0), 5.0)
	aplicar_hit_stop(0.08, 0.06)
	sacudir_camara(1.5, 0.15)

func mostrar_cuadro(animacion: String, cuadro: int) -> void:
	if not ani.sprite_frames.has_animation(animacion):
		return
	ani.animation = animacion
	ani.stop()
	ani.frame = cuadro

# Cada fase usa su animación ("Agarre", "Agarre_Sujeta", "Agarre_Lanza") si está dibujada;
# si falta, sigue la anterior o se usa una pose provisional.
func mostrar_animacion_agarre(fase: String) -> void:
	if ani.sprite_frames.has_animation(fase):
		ani.play(fase)
		return
	if fase == "Agarre_Sujeta" and ani.animation == "Agarre":
		return
	var pose = obtener_pose_agarre(fase == "Agarre_Lanza")
	mostrar_cuadro(pose[0], pose[1])

# Pose provisional [animación, cuadro]; cada personaje puede dar la suya.
func obtener_pose_agarre(_lanzando: bool) -> Array:
	return ["Idle", 0]

func duracion_animacion(nombre: String) -> float:
	if not ani.sprite_frames.has_animation(nombre):
		return 0.0
	var velocidad = ani.sprite_frames.get_animation_speed(nombre)
	if velocidad <= 0.0:
		return 0.0
	var total := 0.0
	for i in ani.sprite_frames.get_frame_count(nombre):
		total += ani.sprite_frames.get_frame_duration(nombre, i)
	return total / velocidad

func mostrar_pose_derribado() -> void:
	if ani.sprite_frames.has_animation("Derribado"):
		ani.play("Derribado")
	elif ani.sprite_frames.has_animation("Caida"):
		mostrar_cuadro("Caida", ani.sprite_frames.get_frame_count("Caida") - 1)
	else:
		# Sin animación de caída, el sprite se acuesta con la cabeza hacia donde salió volando.
		ani.rotation_degrees = 90.0 * direccion_agarre
		ani.position = posicion_sprite_base + Vector2(0, 4)

func reiniciar_para_ronda(posicion_inicial: Vector2, direccion_inicial: int) -> void:
	id_hitstun_actual += 1
	vida = vida_maxima
	estado = EstadoFSM.NORMAL
	velocity = Vector2.ZERO
	intMove = 0
	Can_Dash = 1
	coyote_time = 0.0
	tiempo_impacto_bloqueo = 0.0
	tiempo_choque = 0.0
	limpiar_agarre()
	desactivar_hitboxes()
	global_position = posicion_inicial
	mirar_hacia(direccion_inicial)
	ani.play("Idle")

func sacudir_camara(intensidad: float = 1, duracion: float = 0.1):
	var camara = get_tree().get_first_node_in_group("camara_principal")
	if camara:
		camara.sacudir(intensidad, duracion)

func Hit(posicion_atacante = null, tiempo: float = -1.0):
	if estado == EstadoFSM.MUERTO:
		return

	# Si lo golpean mientras intenta agarrar, el agarre se cancela.
	limpiar_agarre()
	# Un personaje golpeado no debe conservar la hitbox ni la animacion ofensiva.
	desactivar_hitboxes()
	if is_instance_valid(anim_player):
		anim_player.call_deferred("stop")

	estado = EstadoFSM.HITSTUN
	id_hitstun_actual += 1
	var id_local = id_hitstun_actual
	var tiempo_final = duración_hitstun if tiempo < 0 else tiempo

	if posicion_atacante != null:
		velocity.x = fuerza_golpe if posicion_atacante.x < global_position.x else -fuerza_golpe
	else:
		var dir = sign(mirror.scale.x)
		if dir == 0: dir = 1
		velocity.x = -dir * fuerza_golpe

	if ani.sprite_frames and ani.sprite_frames.has_animation("Hit"):
		ani.play("Hit")

	# En tiempo de juego: durante el congelado del golpe casi no avanza, así el
	# hitstun completo empieza a contar cuando termina el congelado.
	var timer = get_tree().create_timer(tiempo_final, false)
	timer.timeout.connect(func():
		if is_instance_valid(self) and estado == EstadoFSM.HITSTUN and id_local == id_hitstun_actual:
			estado = EstadoFSM.NORMAL
			ani.play("Idle")
	)

func _on_hurtbox_area_entered(area: Area2D):
	if estado == EstadoFSM.MUERTO:
		return
	# Mientras dura un agarre no se le puede pegar ni al que agarra ni al agarrado.
	if es_invulnerable_por_agarre():
		return

	if area.is_in_group("P_Punch"):
		var atacante_melee = area.get_parent() if area.get_parent() is Jugador else null
		if atacante_melee != null and atacante_melee != self:
			# Si ya chocaron, el golpe del rival quedó anulado.
			if estado == EstadoFSM.CHOQUE or atacante_melee.estado == EstadoFSM.CHOQUE:
				return
			# Si los dos golpes se tocan en el mismo instante, gana el choque: nadie recibe daño.
			var punto_choque = buscar_choque_con(atacante_melee)
			if punto_choque != null:
				resolver_choque(atacante_melee, punto_choque)
				return

		# El impacto del bloqueo también protege: los golpes seguidos se siguen bloqueando.
		var ignora_bloqueo = "ignora_bloqueo" in area and area.ignora_bloqueo
		if not ignora_bloqueo and (estado == EstadoFSM.BLOQUEANDO or estado == EstadoFSM.BLOQUEO_IMPACTO):
			reaccionar_bloqueo(area)
			return

		var daño_recibido = 10
		var atacante = area.get_parent()
		if atacante != null and atacante.has_method("obtener_daño_actual"):
			daño_recibido = atacante.obtener_daño_actual()
		if "daño" in area:
			daño_recibido = area.daño

		var tiempo_hitstun = duración_hitstun
		if "duración_hitstun" in area:
			tiempo_hitstun = area.duración_hitstun
		if atacante != null and atacante.has_method("obtener_hitstun_actual"):
			tiempo_hitstun = atacante.obtener_hitstun_actual(tiempo_hitstun)

		vida -= daño_recibido
		vida_cambiada.emit(vida)
		aplicar_hit_stop()
		sacudir_camara()   
		crear_hit_spark(calcular_punto_contacto(area), Color(1, 1, 0.5, 1.0), 5.5)
		
		if vida <= 0:
			morir()
		else:
			Hit(area.global_position, tiempo_hitstun)
		# Solo los golpes que entran (no los bloqueados ni los choques).
		if atacante != null and atacante != self and atacante.has_method("al_conectar_golpe"):
			atacante.al_conectar_golpe(self)

func morir(reproducir_caida: bool = true) -> void:
	vida = 0
	estado = EstadoFSM.MUERTO
	velocity = Vector2.ZERO
	desactivar_hitboxes()
	if is_instance_valid(anim_player):
		anim_player.call_deferred("stop")
	if reproducir_caida and ani.sprite_frames.has_animation("Caida"):
		ani.play("Caida")

func _animaciones():
	if intMove == -1:
		mirror.scale.x = -1
		col_dano.scale.x = -1
	elif intMove == 1:
		mirror.scale.x = 1
		col_dano.scale.x = 1

func mirar_hacia(dir: int):
	mirror.scale.x = dir
	col_dano.scale.x = dir

func _on_animation_player_finished(anim_name: String) -> void:
	match anim_name:
		"Ataque_1", "Especial":
			if estado == EstadoFSM.ATACANDO or estado == EstadoFSM.ESPECIAL:
				estado = EstadoFSM.NORMAL
		"Ataque_2":
			if estado == EstadoFSM.ESTOCADA_VELOZ:
				return
			if estado == EstadoFSM.ATACANDO:
				estado = EstadoFSM.NORMAL
				
func procesar_pushbox() -> void:
	if not is_instance_valid(pushbox) or estado == EstadoFSM.MUERTO:
		return
	
	var areas = pushbox.get_overlapping_areas()
	for area in areas:
		if area.is_in_group("pushbox") and area != pushbox:
			var rival = area.get_parent()
			if rival is Jugador and rival.estado != EstadoFSM.MUERTO:
				var distancia_x = global_position.x - rival.global_position.x
				
				# Ancho combinado: calculamos a partir de las formas o usamos 20.0 por defecto
				var ancho_combinado = 20.0
				var mi_shape = pushbox.get_node_or_null("CollisionShape2D")
				var rival_shape = area.get_node_or_null("CollisionShape2D")
				if mi_shape and mi_shape.shape is RectangleShape2D and rival_shape and rival_shape.shape is RectangleShape2D:
					ancho_combinado = (mi_shape.shape.size.x + rival_shape.shape.size.x) * 0.5
				
				if abs(distancia_x) < ancho_combinado:
					var solapamiento = ancho_combinado - abs(distancia_x)
					var direccion = sign(distancia_x)
					if direccion == 0:
						direccion = 1 if player_id == 1 else -1
					
					# Si estamos pegados al borde de la pantalla, empujamos más al rival; si no, repartimos 50/50
					global_position.x += direccion * (solapamiento * 0.5)
					global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)
