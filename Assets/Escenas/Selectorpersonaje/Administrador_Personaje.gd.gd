extends Control

var seleccion_p1 : String = ""
var seleccion_p2 : String = ""

func _ready():
	$VBoxContainerPrincipal/BoxContainerJugadores/P1Panel/Jugador1/BotonLum.pressed.connect(func(): elegir_p1("Lum"))
	$VBoxContainerPrincipal/BoxContainerJugadores/P1Panel/Jugador1/ButtonSierv.pressed.connect(func(): elegir_p1("Sierv"))
	$VBoxContainerPrincipal/BoxContainerJugadores/P2Panel/Jugador2/BotonLum.pressed.connect(func(): elegir_p2("Lum"))
	$VBoxContainerPrincipal/BoxContainerJugadores/P2Panel/Jugador2/ButtonSierv.pressed.connect(func(): elegir_p2("Sierv"))
	$BotonConfirmar.pressed.connect(_on_confirmar_pressed)
	$BotonConfirmar.disabled = true

func elegir_p1(nombre: String):
	seleccion_p1 = nombre
	$VBoxContainerPrincipal/BoxContainerJugadores/P1Panel/Jugador1/Label.text = "Elegido: " + nombre
	_revisar_listos()

func elegir_p2(nombre: String):
	seleccion_p2 = nombre
	$VBoxContainerPrincipal/BoxContainerJugadores/P2Panel/Jugador2/Label.text = "Elegido: " + nombre
	_revisar_listos()

func _revisar_listos():
	$BotonConfirmar.disabled = seleccion_p1 == "" or seleccion_p2 == ""

func _on_confirmar_pressed():
	AdministradorPartida.elegir_personaje_p1(seleccion_p1)
	AdministradorPartida.elegir_personaje_p2(seleccion_p2)
	get_tree().change_scene_to_file("res://Assets/Niveles/level.tscn")
