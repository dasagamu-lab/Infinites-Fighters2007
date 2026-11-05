extends Control

const ESCENA_ENTRENAMIENTO = "res://Assets/Niveles/Entrenamiento.tscn"

# Nombres tal como están en AdministradorPartida.personajes_disponibles
@export var personajes : Array[String] = ["Lum", "Sierv"]

# Arrastra aquí, en el Inspector, una imagen de vista previa por cada
# personaje de la lista de arriba, EN EL MISMO ORDEN (Lum primero, Sierv segundo)
@export var texturas : Array[Texture2D] = []

var indice := 0
var fase := 1  # 1 = eligiendo P1, 2 = eligiendo P2

@onready var vista = $Vista
@onready var label_turno = $LabelTurno

func _ready():
	$Anterior.pressed.connect(_on_anterior)
	$Siguiente.pressed.connect(_on_siguiente)
	$Seleccionar.pressed.connect(_on_seleccionar)
	actualizar_vista()

func _on_anterior():
	indice = (indice - 1 + personajes.size()) % personajes.size()
	actualizar_vista()

func _on_siguiente():
	indice = (indice + 1) % personajes.size()
	actualizar_vista()

func actualizar_vista():
	if texturas.size() > indice:
		vista.texture = texturas[indice]
	if AdministradorPartida.modo_entrenamiento:
		label_turno.text = "Entrenamiento"
	else:
		label_turno.text = "Jugador 1 " if fase == 1 else "Jugador 2 "

func _on_seleccionar():
	var nombre = personajes[indice]

	if fase == 1:
		AdministradorPartida.elegir_personaje_p1(nombre)
		# En entrenamiento solo juega el jugador 1 contra el muñeco.
		if AdministradorPartida.modo_entrenamiento:
			get_tree().change_scene_to_file(ESCENA_ENTRENAMIENTO)
			return
		fase = 2
		indice = 0
		actualizar_vista()
	else:
		AdministradorPartida.elegir_personaje_p2(nombre)
		get_tree().change_scene_to_file("res://Assets/Niveles/level.tscn")
