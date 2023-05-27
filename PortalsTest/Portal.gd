extends Node3D

@export var group_name = "Player"
@export var portal_id = 0
@onready var subport = $PortalView
@onready var viewport_cam = subport.get_camera_3d()
@onready var projection_screen = $Screen

var linked = false
var linked_portal
var teleported = false

var teleporter_list = []
var teleporter_last_pos_list = []



func _ready():
	if get_tree().has_group(group_name):
		subport.size = get_tree().get_root().get_viewport().size
	try_to_link()
	
func _physics_process(delta):
	if linked:
		translate_viewport_camera()
		check_teleport()
		protect_screen_from_clipping()
	

func translate_viewport_camera():
	#check for player node otherwise we crash and burn, also check to see if there is a portal linked, or we crash and burn
	if get_tree().has_group(group_name):
		if linked_portal != null:
			var viewport_pos = global_transform.affine_inverse() * linked_portal.global_transform * get_tree().get_nodes_in_group(group_name)[0].camera.global_transform
			viewport_cam.global_transform = viewport_pos
			

func link_portal(portal_to_link):
	if portal_to_link.portal_id == portal_id && !linked && portal_to_link != self:
		linked_portal = portal_to_link
		linked = true
		return true
	else:
		return false
		
func try_to_link():
	for portal in get_tree().get_nodes_in_group("Portals"):
		if portal.link_portal(self):
			break



func check_teleport():
	if teleporter_list.size() != 0:
		var limit = teleporter_list.size()
		for i in limit:
			var teleportee = teleporter_list[i]
			var teleportee_previous_offset_from_portal = teleporter_last_pos_list[i]
			var teleporteeT = teleportee.global_transform
			var offset_from_portal = teleporteeT.origin - global_transform.origin
			var portal_side = sign(offset_from_portal.dot(-global_transform.basis.z))
			var portal_side_old = sign(teleportee_previous_offset_from_portal.dot(-global_transform.basis.z))
				
			if portal_side != portal_side_old:
				var viewport_pos = global_transform.affine_inverse() * linked_portal.global_transform * get_tree().get_nodes_in_group(group_name)[0].camera.global_transform
				
				
				teleportee.global_transform.origin = viewport_pos.origin - get_tree().get_nodes_in_group(group_name)[0].camera.transform.origin
				
				
				teleporter_list.remove_at(i)
				teleporter_last_pos_list.remove_at(i)
			else:
				teleportee_previous_offset_from_portal = offset_from_portal

func protect_screen_from_clipping():
	var half_height = get_tree().get_nodes_in_group(group_name)[0].camera.near * tan(deg_to_rad(get_tree().get_nodes_in_group(group_name)[0].camera.fov * 0.5))
	var half_width = half_height * DisplayServer.window_get_size().aspect()
	var dst_to_near_clip_plane_corner = Vector3(half_width,half_height,get_tree().get_nodes_in_group(group_name)[0].camera.near).length()
	
	var screenT = projection_screen.global_transform
	var cam_facing_same_dir_as_portal = Vector3(0,0,-global_transform.origin.z).dot(global_transform.origin - get_tree().get_nodes_in_group(group_name)[0].camera.global_transform.origin) > 0
	var new_scale = screenT.scaled(Vector3(screenT.basis.get_scale().x,screenT.basis.get_scale().y,dst_to_near_clip_plane_corner))
	new_scale = new_scale.basis.get_scale()
	projection_screen.mesh.size.y = new_scale[1]
	screenT = screenT.translated(Vector3(0,0,-global_transform.origin.z) * dst_to_near_clip_plane_corner * (0.5 if cam_facing_same_dir_as_portal else -0.5))

func _on_area_3d_body_entered(body):
	var teleportee = body
	var teleportee_previous_offset_from_portal = teleportee.global_transform.origin - global_transform.origin
	if teleporter_list.has(body):
		pass
	else:
		teleporter_list.append(body)
		teleporter_last_pos_list.append(teleportee_previous_offset_from_portal)

func _on_area_3d_body_exited(body):
	teleported = false
	teleporter_list.clear()
	teleporter_last_pos_list.clear()
