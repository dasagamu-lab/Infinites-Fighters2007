extends Area2D

var speed = 300
var direction = 1
var daño: int = 10
var duración_hitstun: float = 0.35
@export var vida_util: float = 8.0

var owner_player: Node2D = null

func _ready():
	if direction < 0:
		scale.x = -1
	var timer = get_tree().create_timer(vida_util, false)
	timer.timeout.connect(func():
		if is_instance_valid(self):
			destruir()
	)

func _physics_process(delta):
	position.x += speed * direction * delta

func _on_body_entered(body):
	# Ignorar el jugador que lo disparó si el cuerpo entra en contacto
	if body == owner_player or (owner_player != null and body == owner_player.get_parent()):
		return

func _on_area_entered(area: Area2D):
	if area.is_in_group("P_Punch") or area.is_in_group("pushbox"):
		return
	if owner_player != null and (area == owner_player or area.get_parent() == owner_player):
		return
	# Si toca una Hurtbox enemiga, impacta y se destruye
	destruir()

func destruir():
	var rastro = get_node_or_null("Rastro")
	if rastro:
		rastro.emitting = false
		if rastro.get_parent() != null and get_parent() != null:
			rastro.reparent(get_parent())
			# Obtener tiempo de vida seguro según el tipo de nodo de partículas (CPU/GPU)
			var time = rastro.lifetime if "lifetime" in rastro else 1.0
			var timer = get_tree().create_timer(time, false)
			timer.timeout.connect(func():
				if is_instance_valid(rastro):
					rastro.queue_free()
			)
			
	queue_free()
