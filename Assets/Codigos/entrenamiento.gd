extends Node2D

# Escena de entrenamiento: solo el jugador 1 contra el muñeco, sin rondas ni KO.
# El muñeco avisa cada golpe y aquí se muestra el daño y el combo.

const MENU := "res://Assets/Otros/Animaciones/Menu/menu.tscn"

var jugador : Jugador

@onready var camara = $Camera2D
@onready var muneco = $Dummy
@onready var label_contador = $HUD/Control/LabelContador
@onready var menu_pausa = $MenuPausa
@onready var boton_reanudar = $MenuPausa/Control/Botones/Reanudar
@onready var boton_menu = $MenuPausa/Control/Botones/Menu

func _ready():
	menu_pausa.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_pausa.visible = false
	boton_reanudar.pressed.connect(_on_reanudar_pressed)
	boton_menu.pressed.connect(_on_menu_pressed)
	# En pausa la escena no recibe teclas, pero el menú de pausa sí:
	# Esc funciona como atajo del botón "Reanudar".
	var atajo = Shortcut.new()
	var tecla_esc = InputEventAction.new()
	tecla_esc.action = "ui_cancel"
	atajo.events = [tecla_esc]
	boton_reanudar.shortcut = atajo

	var escena = AdministradorPartida.personaje_p1
	if escena == null:
		escena = AdministradorPartida.personajes_disponibles["Lum"]
	jugador = escena.instantiate()
	jugador.player_id = 1
	jugador.name = "Player"
	jugador.global_position = $Spawn1.global_position
	add_child(jugador)
	jugador.mirar_hacia(1)
	ajustar_limites_escenario(jugador)

	muneco.golpe_recibido.connect(_on_golpe_recibido)
	actualizar_contador(0, 0, 0)

func ajustar_limites_escenario(j: Jugador) -> void:
	var mitad_visible = get_viewport_rect().size.x * 0.5 / camara.zoom.x
	var margen = 10.0
	j.limite_izquierdo = camara.global_position.x - mitad_visible + margen
	j.limite_derecho = camara.global_position.x + mitad_visible - margen

func _on_golpe_recibido(daño: int, golpes_combo: int, daño_combo: int) -> void:
	actualizar_contador(daño, golpes_combo, daño_combo)

func actualizar_contador(daño: int, golpes_combo: int, daño_combo: int) -> void:
	label_contador.text = "Golpe: %d\nCombo: %d (%d)" % [daño, golpes_combo, daño_combo]

# --- CONTROL DE PAUSA ---

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_on_reanudar_pressed()
		else:
			pausar_juego()

func pausar_juego():
	get_tree().paused = true
	menu_pausa.visible = true

func _on_reanudar_pressed():
	get_tree().paused = false
	menu_pausa.visible = false

func _on_menu_pressed():
	get_tree().paused = false
	AdministradorPartida.modo_entrenamiento = false
	get_tree().change_scene_to_file(MENU)
