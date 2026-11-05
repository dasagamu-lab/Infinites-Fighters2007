extends Node

# Guarda la escena (.tscn) del personaje elegido por cada jugador.
# Se llenan desde el selector de personajes (Paso 3) y se leen
# desde el nivel de pelea (Paso 5).
var personaje_p1 : PackedScene = null
var personaje_p2 : PackedScene = null

# true cuando se entra con el botón "Entrenamiento" del menú: el selector
# solo pide al jugador 1 y lleva a la escena de entrenamiento.
var modo_entrenamiento := false

# Rutas de las escenas de personaje disponibles.
# Cuando agregues un personaje nuevo, solo lo sumas aquí.
var personajes_disponibles := {
	"Lum": preload("res://Assets/Escenas/Lum/Lum.tscn"),
	"Sierv": preload("res://Assets/Escenas/Sierv/Sierv.tscn")
}

func elegir_personaje_p1(nombre: String):
	personaje_p1 = personajes_disponibles[nombre]

func elegir_personaje_p2(nombre: String):
	personaje_p2 = personajes_disponibles[nombre]
