extends CharacterBody2D
class_name Jugador

signal vida_cambiada(nueva_vida: int)

@export var player_id : int = 1
var HitSpark = preload("res://Assets/Escenas/HitSpark.tscn")
# Diccionario de controles: qué acción de Input usa este jugador
var inputs := {}


func crear_hit_spark(posicion: Vector2, color: Color = Color(1, 1, 0.6, 1.0)):
	var spark = HitSpark.instantiate()
	spark.global_position = posicion
	spark.color = color
	get_tree().current_scene.add_child(spark)

func _ready():
	if player_id == 1:
		$Hurtbox.collision_layer = 2    # Hurtbox_P1
		$Hurtbox.collision_mask = 16    # detecta ataques de P2
		$Col_Daño.collision_layer = 8   # Ataque_P1
		$Col_Daño.collision_mask = 0
	else:
		$Hurtbox.collision_layer = 4    # Hurtbox_P2
		$Hurtbox.collision_mask = 8     # detecta ataques de P1
		$Col_Daño.collision_layer = 16 # Ataque_P2
		$Col_Daño.collision_mask = 0
		
	if player_id == 1:
		inputs = {
			"ataque_debil": "Ataque_1",
			"ataque_medio": "Ataque_2",
			"bloqueo": "Bloqueo",
			"especial": "Especial",
			"abajo": "Abajo",
			"derecha": "Derecha",
			"izquierda": "Izquierda",
			"dash": "Dash",
			"salto": "Saltar"
		}
	else:
		inputs = {
			"ataque_debil": "ataque_debil_P2",
			"ataque_medio": "ataque_medio_P2",
			"bloqueo": "Bloqueo_P2",
			"especial": "Especial_P2",
			"abajo": "Abajo_P2",
			"derecha": "Derecha_P2",
			"izquierda": "Izquierda_P2",
			"dash": "Dash_P2",
			"salto": "Salto_P2"
		}


# VELOCIDADES Y FÍSICAS (Compartidas)
var intVX : int = 10000
var intVY : int = 480
var intVX_Dash : int = 18000
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

func desactivar_hitboxes():
	$Col_Daño/Ataque_1.disabled = true
	$Col_Daño/Ataque_2.disabled = true

# ESTADÍSTICAS GLOBALES (Configurables desde el Inspector)
@export var vida : int = 100
@export var fuerza_golpe : int = 120
@export var duración_hitstun : float = 0.35 # Modifica el tiempo base desde el Inspector de Godot

@export_category("Daño de ataques")
@export var daño_ataque_debil : int = 10
@export var daño_ataque_medio : int = 20
@export var daño_especial : int = 30

var tipo_ataque_actual : String = "debil"

# ESTADOS GLOBALES
var estado : String = "Normal"
var intMove : int = 0
var Can_Dash : int = 2
var id_hitstun_actual : int = 0 # Identificador para gestionar el reinicio de aturdimiento en combos

func configurar_ataque(tipo: String) -> void:
	tipo_ataque_actual = tipo


func obtener_daño_actual() -> int:
	match tipo_ataque_actual:
		"medio":
			return daño_ataque_medio
		"especial":
			return daño_especial
		_:
			return daño_ataque_debil

# NODOS VISUALES
@onready var ani = $AnimatedSprite2D
@onready var mirror = $AnimatedSprite2D


func aplicar_hit_stop(duracion: float = 0.20, escala: float = 0.06):
	Engine.time_scale = escala
	await get_tree().create_timer(duracion, false, false, true).timeout
	Engine.time_scale = 1.0

func sacudir_camara(intensidad: float = 1, duracion: float = 0.1):
	var camara = get_tree().get_first_node_in_group("camara_principal")
	if camara:
		camara.sacudir(intensidad, duracion)


# --- SISTEMA DE HITSTUN Y RECEPCIÓN DE GOLPES ---

func Hit(posicion_atacante = null, tiempo: float = -1.0):
	if estado == "Muerto":
		return

	# Cambiar a estado Hitstun inmediatamente
	estado = "Hitstun"

	# Incrementar contador local para permitir reinicio en combos
	id_hitstun_actual += 1
	var id_local = id_hitstun_actual

	# Usar duración de la variable exportada si no se pasa una específica
	var tiempo_final = duración_hitstun if tiempo < 0 else tiempo

	# Aplicar fuerza de empuje horizontal (Knockback)
	if posicion_atacante != null:
		if posicion_atacante.x < global_position.x:
			velocity.x = fuerza_golpe
		else:
			velocity.x = -fuerza_golpe
	else:
		var dir = -1 if mirror.flip_h else 1
		velocity.x = -dir * fuerza_golpe

	if ani.sprite_frames and ani.sprite_frames.has_animation("Hit"):
		ani.play("Hit")

	# Esperar el tiempo exacto de aturdimiento
	await get_tree().create_timer(tiempo_final, false, false, true).timeout

	# Solo restaura a estado Normal si no ha recibido un golpe nuevo dentro del combo
	if estado == "Hitstun" and id_local == id_hitstun_actual:
		estado = "Normal"
		ani.play("Idle")


func _on_hurtbox_area_entered(area: Area2D):
	if estado == "Muerto":
		return

	if area.is_in_group("P_Punch"):
		
		# --- NUEVA LÓGICA DE BLOQUEO ---
		if estado == "Bloqueando":
			print(name + " ¡BLOQUEÓ EL GOLPE EXITOSAMENTE!")
			aplicar_hit_stop(0.05, 0.5)
			sacudir_camara(0.5, 0.05)
			var punto_contacto = (area.global_position + global_position) / 2.0
			punto_contacto.y -= 60  # sube el punto a la altura del torso — ajusta este número a ojo
			crear_hit_spark(punto_contacto)
			var dir_empuje = 1 if area.global_position.x < global_position.x else -1
			velocity.x = dir_empuje * (fuerza_golpe * 0.9)
			return # Corta aquí para que NO reciba daño ni entre en Hitstun
		# -------------------------------

		# Si NO está bloqueando, recibe el golpe normal:
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
		crear_hit_spark(global_position)
		
		if vida <= 0:
			vida = 0
			estado = "Muerto"
			ani.play("Caida")
		else:
			Hit(area.global_position, tiempo_hitstun)

# Corta la ejecución de físicas normales y movimientos controlados por el jugador


	# Si tu script tiene funciones de ataque asociadas a inputs, procesalas aquí abajo:
	# (Ejemplo: if event.is_action_pressed(inputs["ataque_debil"]): atacar_debil())

func _animaciones():
	if intMove == -1:
		mirror.scale.x = -1
		$Col_Daño.scale.x = -1
	elif intMove == 1:
		mirror.scale.x = 1
		$Col_Daño.scale.x = 1


func mirar_hacia(dir: int):
	mirror.scale.x = dir
	$Col_Daño.scale.x = dir
