extends CharacterBody2D
class_name Jugador

signal vida_cambiada(nueva_vida: int)

@export var player_id : int = 1
var HitSpark = preload("res://Assets/Escenas/HitSpark.tscn")
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
	ESTOCADA_VELOZ, ANTIAEREO, COUNTER_POSE, COUNTER_IMPACTO, COUNTER_ATTACK, BLOQUEO_IMPACTO
}

# ESTADOS GLOBALES
var estado: EstadoFSM = EstadoFSM.NORMAL
var intMove : int = 0
var Can_Dash : int = 2
var id_hitstun_actual : int = 0
var tipo_ataque_actual : String = "debil"
var tiempo_impacto_bloqueo : float = 0.0
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

func _ready():
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
			"izquierda": "Izquierda", "dash": "Dash", "salto": "Saltar", "counter": "Counter"
		}
	else:
		inputs = {
			"ataque_debil": "ataque_debil_P2", "ataque_medio": "ataque_medio_P2",
			"bloqueo": "Bloqueo_P2", "especial": "Especial_P2", "abajo": "Abajo_P2",
			"derecha": "Derecha_P2", "izquierda": "Izquierda_P2", "dash": "Dash_P2",
			"salto": "Salto_P2", "counter": "Counter_P2"
		}
	
	if is_instance_valid(anim_player):
		anim_player.animation_finished.connect(_on_animation_player_finished)

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
	return is_on_floor() and estado != EstadoFSM.BLOQUEANDO and estado != EstadoFSM.ATACANDO

func puede_cancelar_ataque_debil(nombre_ataque_debil: String) -> bool:
	return estado == EstadoFSM.ATACANDO and ani.animation == nombre_ataque_debil and ani.frame >= frame_cancel_debil

func procesar_entrada_bloqueo() -> void:
	if Input.is_action_pressed(inputs["bloqueo"]):
		if is_on_floor() and (estado == EstadoFSM.NORMAL or estado == EstadoFSM.AGACHADO):
			estado = EstadoFSM.BLOQUEANDO
			iniciar_animacion_bloqueo()
	if Input.is_action_just_released(inputs["bloqueo"]) and estado == EstadoFSM.BLOQUEANDO:
		estado = EstadoFSM.NORMAL

func procesar_postura() -> void:
	if Input.is_action_pressed(inputs["abajo"]) and is_on_floor() and estado == EstadoFSM.NORMAL:
		estado = EstadoFSM.AGACHADO
	elif Input.is_action_just_released(inputs["abajo"]) and is_on_floor() and estado == EstadoFSM.AGACHADO:
		estado = EstadoFSM.NORMAL

func actualizar_direccion_entrada() -> void:
	if estado == EstadoFSM.BLOQUEANDO or estado == EstadoFSM.ATACANDO or estado == EstadoFSM.ESPECIAL or estado == EstadoFSM.HITSTUN:
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
	return true

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
	duplicado.global_scale = ani.global_scale
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
	if estado != EstadoFSM.BLOQUEANDO:
		return

	var direccion = 1 if area.global_position.x < global_position.x else -1
	estado = EstadoFSM.BLOQUEO_IMPACTO
	tiempo_impacto_bloqueo = duracion_impacto_bloqueo
	velocity.x = direccion * retroceso_bloqueo
	velocity.y = 0
	aplicar_hit_stop(hitstop_bloqueo, 0.08)
	sacudir_camara(intensidad_camara_bloqueo, hitstop_bloqueo)
	
	# Colocar el spark de bloqueo justo en la zona donde la hitbox contacta con la hurtbox
	var punto_contacto = Vector2(
		(area.global_position.x + hurtbox.global_position.x) * 0.5,
		(area.global_position.y + hurtbox.global_position.y) * 0.5
	)
	crear_hit_spark(punto_contacto, Color(0.5, 0.8, 1.0, 1.0), 4.5)
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

func reiniciar_para_ronda(posicion_inicial: Vector2, direccion_inicial: int) -> void:
	id_hitstun_actual += 1
	vida = 100
	estado = EstadoFSM.NORMAL
	velocity = Vector2.ZERO
	intMove = 0
	Can_Dash = 1
	coyote_time = 0.0
	tiempo_impacto_bloqueo = 0.0
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

	var timer = get_tree().create_timer(tiempo_final, false, false, true)
	timer.timeout.connect(func():
		if is_instance_valid(self) and estado == EstadoFSM.HITSTUN and id_local == id_hitstun_actual:
			estado = EstadoFSM.NORMAL
			ani.play("Idle")
	)

func _on_hurtbox_area_entered(area: Area2D):
	if estado == EstadoFSM.MUERTO:
		return

	if area.is_in_group("P_Punch"):
		if estado == EstadoFSM.BLOQUEANDO:
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

		vida -= daño_recibido
		vida_cambiada.emit(vida)
		aplicar_hit_stop()
		sacudir_camara()   
		var punto_golpe = Vector2(
			(area.global_position.x + hurtbox.global_position.x) * 0.5,
			(area.global_position.y + hurtbox.global_position.y) * 0.5
		)
		crear_hit_spark(punto_golpe, Color(1, 1, 0.5, 1.0), 5.5)
		
		if vida <= 0:
			vida = 0
			estado = EstadoFSM.MUERTO
			velocity = Vector2.ZERO
			desactivar_hitboxes()
			if is_instance_valid(anim_player):
				anim_player.call_deferred("stop")
			ani.play("Caida")
		else:
			Hit(area.global_position, tiempo_hitstun)

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
