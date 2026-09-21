extends Node2D

const RONDAS_PARA_GANAR := 2

var jugador1 : Jugador
var jugador2 : Jugador

var rondas_p1 := 0
var rondas_p2 := 0
var ronda_terminada_ya := false
var numero_ronda := 1




@onready var barra_p1 = $HUD/Control/BarraVidaP1
@onready var barra_p2 = $HUD/Control/BarraVidaP2
@onready var label_marcador = $HUD/Control/LabelMarcador
@onready var label_anuncio = $HUD/Control/LabelAnuncio
@onready var pantalla_victoria = $HUD/Control/PantallaVictoria
@onready var label_ganador = $HUD/Control/PantallaVictoria/LabelGanador

# Referencias directas al Menú de Pausa
@onready var menu_pausa = $MenuPausa
@onready var boton_reanudar = $MenuPausa/Control/Botones/Reanudar
@onready var boton_menu_pausa = $MenuPausa/Control/Botones/Menu

func _ready():
	# Permitir que el menú de pausa procese clics cuando el juego está pausado
	menu_pausa.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_pausa.visible = false

	# Conexión correcta de botones del menú de pausa
	if boton_reanudar:
		boton_reanudar.pressed.connect(_on_reanudar_pressed)
	if boton_menu_pausa:
		boton_menu_pausa.pressed.connect(_on_menu_pausa_pressed)

	if AdministradorPartida.personaje_p1 == null:
		AdministradorPartida.personaje_p1 = AdministradorPartida.personajes_disponibles["Lum"]
	if AdministradorPartida.personaje_p2 == null:
		AdministradorPartida.personaje_p2 = AdministradorPartida.personajes_disponibles["Sierv"]

	jugador1 = spawnear_jugador(AdministradorPartida.personaje_p1, 1, $Spawn1)
	jugador2 = spawnear_jugador(AdministradorPartida.personaje_p2, 2, $Spawn2)

	pantalla_victoria.visible = false
	$HUD/Control/PantallaVictoria/Botones/VolverAJugar.pressed.connect(_on_volver_pressed)
	$HUD/Control/PantallaVictoria/Botones/Menu.pressed.connect(_on_menu_pausa_pressed)
	$HUD/Control/PantallaVictoria/Botones/BotonVolver.pressed.connect(_on_menu_pausa_pressed)
	$HUD/Control/PantallaVictoria/Botones/BotonVolver.pressed.connect(_on_volver_pressed)

	actualizar_marcador()

	congelar_jugadores(true)
	anuncio_ronda()

func spawnear_jugador(escena: PackedScene, id: int, punto_spawn: Node2D) -> Jugador:
	var jugador = escena.instantiate()
	jugador.player_id = id
	jugador.name = "Player" if id == 1 else "Player2"
	jugador.global_position = punto_spawn.global_position
	add_child(jugador)
	jugador.mirar_hacia(1 if id == 1 else -1)

	var barra = barra_p1 if id == 1 else barra_p2
	jugador.vida_cambiada.connect(func(nueva_vida): _on_vida_cambiada(id, nueva_vida, barra))

	return jugador

func congelar_jugadores(congelado: bool):
	jugador1.set_physics_process(not congelado)
	jugador1.set_process_input(not congelado)
	jugador2.set_physics_process(not congelado)
	jugador2.set_process_input(not congelado)

func anuncio_ronda():
	label_anuncio.text = "ROUND " + str(numero_ronda)
	label_anuncio.visible = true
	await get_tree().create_timer(1.2).timeout

	label_anuncio.text = "FIGHT!"
	await get_tree().create_timer(0.8).timeout

	label_anuncio.visible = false
	congelar_jugadores(false)

func _on_vida_cambiada(id: int, nueva_vida: int, barra: ProgressBar):
	barra.value = nueva_vida
	if nueva_vida <= 0 and not ronda_terminada_ya:
		var ganador = 2 if id == 1 else 1
		ronda_terminada(ganador)

func ronda_terminada(ganador: int):
	ronda_terminada_ya = true

	if ganador == 1:
		rondas_p1 += 1
	else:
		rondas_p2 += 1

	actualizar_marcador()

	if rondas_p1 >= RONDAS_PARA_GANAR or rondas_p2 >= RONDAS_PARA_GANAR:
		await get_tree().create_timer(1.5).timeout
		mostrar_pantalla_victoria(ganador)
	else:
		congelar_jugadores(true)
		await get_tree().create_timer(2.0).timeout
		reiniciar_ronda()

func actualizar_marcador():
	label_marcador.text = str(rondas_p1) + "   -   " + str(rondas_p2)

func reiniciar_ronda():
	# Los proyectiles de la ronda anterior no deben sobrevivir al reinicio.
	get_tree().call_group("proyectiles", "queue_free")

	jugador1.reiniciar_para_ronda($Spawn1.global_position, 1)
	barra_p1.value = 100

	jugador2.reiniciar_para_ronda($Spawn2.global_position, -1)
	barra_p2.value = 100

	ronda_terminada_ya = false
	numero_ronda += 1

	anuncio_ronda()

func mostrar_pantalla_victoria(ganador: int):
	label_ganador.text = "¡Jugador " + str(ganador) + " gana la partida!"
	pantalla_victoria.visible = true

func _on_volver_pressed():
	rondas_p1 = 0
	rondas_p2 = 0
	get_tree().change_scene_to_file("res://Assets/Escenas/Selectorpersonaje/SelectorPersonajes.tscn")

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

func _on_menu_pausa_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Assets/Otros/Animaciones/Menu/menu.tscn")
