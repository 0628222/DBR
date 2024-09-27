extends CharacterBody3D

signal health_changed(health_value)
signal ammo_changed(spare_ammo)
signal ammo_Changed(current_ammo)

# Set enumuration values reflect player's current camera view state
enum DynamicCameraViewToggleAction {
	FIRST_PERSON_VIEW,
	THIRD_PERSON_VIEW
}

# First Player View (FPP)

# Animations
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var fpp_camera: Camera3D = $FPPCamera
@onready var fpp_raycast: RayCast3D = $FPPCamera/FPPRayCast3D

# Set player's current camera view state in the editor

# Set positon for the camera when zoomed in or out
@export var zoom_in_position: Vector3 = Vector3(0, 3, -8)
@export var zoom_out_position: Vector3 = Vector3(0, 3, 0)

var health: int = 10
var MAX_HEALTH: int = 10
var max_ammo: int = 30
var current_ammo: int = max_ammo
var current_spare_ammo: int = 90
var needed_spare_ammo: int = 90
var is_reloading: bool = false
var reloaded_ammo: int = clamp(0, 0, 0,)
var reload_time: float = 2.0  # Time in seconds to reload


const HEALTH_AMOUNTS: int = 2
const SPEED: float = 13.0
const JUMP_VELOCITY: float = 10.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = 25.0


# Track the current weapon
var current_weapon: String = ""



func _enter_tree():
	set_multiplayer_authority(str(name).to_int())


func _ready():
	#Global.player = self
	# Connect new 'weapon_switched' signal from the Global script
	var callable_gun_signal = Callable(self, "_on_weapon_switched")
	Global.connect("weapon_switched", callable_gun_signal)
	
	if not is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		fpp_camera.rotate_x(-event.relative.y * .005)
		fpp_camera.rotation.x = clamp(rotation.x, -PI/2, PI/2)
# potential lean mechanic?
#			if event is InputEventMouseMotion:
#		rotate_y(-event.relative.x * .005)
#		rotate_x(-event.relative.y * .005)
#		rotation.x = clamp(rotation.x, -PI/2, PI/2)


	if Input.is_action_just_pressed("shoot"):
		#print("shoot")
		if current_ammo<= 0:
			print("Out of ammo! Reload needed.")
			return #is needed otherwise can shoot without Ammo
		else:
			current_ammo -= 1 
		print("Bang! Ammo left: ", current_ammo)
		print("Bang! Spare_Ammo left:", current_spare_ammo)
		ammo_Changed.emit(current_ammo)
		if is_reloading:
			pass
		#play_shoot_effects.rpc()


var _is_reloading = false
func reload():

	var _is_reloading = true
	print("Reloading...")
	await get_tree().create_timer(reload_time).timeout
	needed_spare_ammo = max_ammo - current_ammo
	reloaded_ammo = clamp(needed_spare_ammo, 0, current_spare_ammo)
	current_ammo += reloaded_ammo
	current_spare_ammo = current_spare_ammo - reloaded_ammo
	print("Reloaded! Ammo refilled to: ", current_ammo)
	
	if current_spare_ammo <= 0:
	#await get_tree().create_timer(reload_delay).timeout
		_is_reloading = false
	else:
		print('already reloading')
#var _is_reloading = false
#func reload():
	#print(_is_reloading)
	#if !_is_reloading:
		#_is_reloading = true
		#print("Reloading...")
		#await get_tree().create_timer(reload_time).timeout
		#current_ammo = spare_ammo 
		#spare_ammo -= spare_ammo
		#_is_reloading = false
		#print("Reloaded! Ammo refilled to: ", current_ammo)
	#else:
		#print("Already reloading")

func _physics_process(delta):
	#print(health)
	Global.current_ammo = current_ammo
	Global.spare_ammo = current_spare_ammo
	
	if not is_multiplayer_authority(): return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")

	move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().is_in_group("pickup"):
			print("pickup collided.")
			if "AmmoBox" in collision.get_collider().name:
				add_ammo(10)
				# Add to Ammo instead.
				print("I collided with ", collision.get_collider().name)
				add_health(1)
				collision.get_collider().queue_free()
			if "Health" in collision.get_collider().name:
				print("I collided with ", collision.get_collider().name)
				add_health(5)
				collision.get_collider().queue_free()


# Get defined key inputs
func _input(event):
# Switch guns in inventory slot according to the key inputs set for it
	if event.is_action_pressed("inventory_slot_1"):
		Global.switch_weapon(1)
	elif event.is_action_pressed("inventory_slot_2"):
		Global.switch_weapon(2)
	elif event.is_action_pressed("inventory_slot_3"):
		Global.switch_weapon(3)

# Switch player's camera view according to the key inputs set for it


# Reload weapon's ammo according to the key inputs set for it 
	if event.is_action_pressed("reload"):
		reload()

func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
@rpc("any_peer")
func receive_damage():
	health -= 1
	print("damage taken")
	if health <= 0:
		print("Game Over!")
		# Reset the player's health and position
		health = MAX_HEALTH
		position = Vector3.ZERO
		# Emit the health_changed signal with the reset health value
		health_changed.emit(health)
	else:
		# Emit the health_changed signal with the updated health value
		health_changed.emit(health)


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")


func add_health(additional_health):
	health += additional_health
	health_changed.emit(health)


func add_ammo(additional_ammo):
	current_ammo += additional_ammo
	ammo_changed.emit(current_spare_ammo)


#func t_body_entered(body):
	##if_area_is_in_group("player")
	#print("added_Health")
	#if body.has_method("add_health"):
		#body.add_health(HEALTH_AMOUNTS)


# Handle weapon switching based on the key inputs
var weaponStatus = null
func _on_weapon_switched(weapon_name):
	print("Switched to weapon: %s" % weapon_name)
	current_weapon = weapon_name
	weaponStatus = weapon_name



# Update player's camera view when player pressed the pre-defined key input

# Default and reduced range values
var default_range = -50.0
var knife_range = -2.0


##################################################################################################################
######      Documentation about synchronising weapon models into multiplayer game in a correct way          ######
##################################################################################################################

## - To prevent the bug where let's say you have 2 player in the multiplayer room, 'Player 1' clicked the key 
##   bind '1' --> that weapon model shows on both 'Player 1' and 'Player 2' character model, but not for the 
##   'Player 2's screen, STRICTLY follow the instruction below to not letting that happens again (I have already 
##   fix it):
##
##		+ Add new weapon models into the 'Player Scene Tree' (the thing on your left if you don't know the term 
##		  for it) under each of the view mode: TPP and FPP (remember to re-name them as how the naming is written 
##		  inside each view mode). 
##
##		  **If you unsure on how to add new weapon models into the 'Player Scene Tree', have a look at the 
##		  'world.gd' file and read the documentation in there. It's very detailise and it should help you to be 
##		  able to achieve this action (although it's not related to the weapon models, but it should be similar 
##		  about the node setup).**
##
##		+ Then, click on the 'MultiplayerSynchronizer' Node (at the end of the 'Player Scene Tree') or click on 
##		  the 'Replication' section (right at the bottom of your eye view if you don't see it)
##
##		+ After that, click on the 'Add property to sync...' button (It's the big ass '+' symbol if you don't see 
##		  it).
##
##		+ After you clicked the button, it'll pop-up and show you the 'Player Scene Tree'. Don't be panic about 
##		  all of the stuff in there yet, this documentation is where your life'll be easier. Clicks on your new 
##		  weapon model (both TPP and FPP view mode, do it one by one because Godot won't let you to be a 'I'm 
##		  fast as fuck boiz').
##
##		+ After you clicked the new weapon model respectively, it'll pop-up and show you all the options that you 
##		  can choose to synchronise across all player. It's alright if you don't get wtf it's happening in 
##		  there, just mindlessly follow this upcoming step to have a happy dev life (you can test out the other 
##		  options on your own if you wanted to). Clicks on the 'visible' property (it's under the 'Node3D' 
##		  section if you don't see it), and do the same for your new weapon models in both view mode.
##
##		+ You have officially made it if you followed the step correctly up to this point. Hooray!

##################################################################################################################
######             End of the Documentation. You may freely to continue working on this now!                ######
##################################################################################################################


# Update the visibility of guns when player changed the camera view based on their preferrance



