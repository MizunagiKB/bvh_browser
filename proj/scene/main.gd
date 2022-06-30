extends Spatial


const BVH_EXT = "bvh"
const JSON_INDENT = "    "
const SCALE: Array = [0.1, 0.5, 1.0, 2.0, 10.0]
const DEFAULT_CAM_H_OFFSET: int = 0
const DEFAULT_CAM_V_OFFSET: int = 100
const DEFAULT_CAM_DISTANCE: float = 500.0
const DEFAULT_CAM_ROT_X: float = -15.0
const DEFAULT_CAM_ROT_Y: float = 0.0

onready var anim_player: AnimationPlayer = $BVHSpatial/AnimationPlayer
onready var anim_mode = $BVHSpatial.E_ANIMATION_MODE.MODE_PREVIEW
onready var anim_node: NodePath = "."

var button_status: int = 0
var preview_node: Spatial
var vct_camera_pos: Vector3 = Vector3(0, 0, DEFAULT_CAM_DISTANCE)
var cam_rot_x: float = DEFAULT_CAM_ROT_X
var cam_rot_y: float = DEFAULT_CAM_ROT_Y

var dict_pathname: Dictionary = {}
var dict_adjust: Dictionary = {}
var current_adjust: BVHSpatial.CAdjust
var reload: bool = false


func scan_file(scan_dir: String, ext: String):

    var dir = Directory.new()

    if dir.open(scan_dir) == OK:
        dir.list_dir_begin()
        var filename = dir.get_next()
        while filename != "":
            if dir.current_is_dir():
                if filename in [".", ".."]:
                    pass
                else:
                    scan_file("%s/%s" % [scan_dir, filename], ext)
            else:
                if filename.get_extension().to_lower() == ext:
                    $ui/bvh_file.add_item(filename)
                    dict_pathname[filename] = "%s/%s" % [scan_dir, filename]
            filename = dir.get_next()


func bvh_reload():

    for index in $ui/bvh_file.get_selected_items():
        reload = true
        _on_bvh_file_item_selected(index)
        break


func _ready():

    current_adjust = null

    for name in dict_adjust.keys():
        $ui/list_adjust.add_item(name)

    for idx in range(BVHSpatial.E_AXIS.AXIS_MAX):
        $ui/axis_x.get_popup().add_check_item(BVHSpatial.ary_axis_name[idx], idx)
        $ui/axis_y.get_popup().add_check_item(BVHSpatial.ary_axis_name[idx], idx)
        $ui/axis_z.get_popup().add_check_item(BVHSpatial.ary_axis_name[idx], idx)

    $ui/axis_x.get_popup().connect("id_pressed", self, "_on_axis_x_changed")
    _on_axis_x_changed(BVHSpatial.E_AXIS.AXIS_RIGHT)
    $ui/axis_y.get_popup().connect("id_pressed", self, "_on_axis_y_changed")
    _on_axis_y_changed(BVHSpatial.E_AXIS.AXIS_UP)
    $ui/axis_z.get_popup().connect("id_pressed", self, "_on_axis_z_changed")
    _on_axis_z_changed(BVHSpatial.E_AXIS.AXIS_BACK)

    $ui/adjust_x.connect("value_changed", self, "_on_adjust_x_value_changed")
    $ui/adjust_y.connect("value_changed", self, "_on_adjust_y_value_changed")
    $ui/adjust_z.connect("value_changed", self, "_on_adjust_z_value_changed")

    $ui/slider_cube_size.connect("value_changed", self, "_on_value_changed")

    $cam_axis/cam.translation = vct_camera_pos
    $cam_axis.rotation_degrees.y = cam_rot_y
    $cam_axis.rotation_degrees.x = cam_rot_x
    $cam_axis/cam.look_at(Vector3.ZERO, Vector3.UP)

    $ui/menu_main/btn_File.get_popup().connect("id_pressed", self, "_on_menu_file")

func _input(event):

    if event is InputEventKey:
        if Input.is_key_pressed(KEY_TAB):
            $ui.visible = $ui.visible != true


func _unhandled_input(event):

    if event is InputEventMouseButton:
        if event.button_index in [BUTTON_LEFT, BUTTON_MIDDLE]:
            if event.pressed:
                button_status = event.button_index
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            else:
                button_status = 0
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        elif event.button_index == BUTTON_WHEEL_DOWN:
            vct_camera_pos.z += 20
        elif event.button_index == BUTTON_WHEEL_UP:
            vct_camera_pos.z -= 20

        $cam_axis/cam.translation = vct_camera_pos
        $cam_axis.rotation_degrees.y = cam_rot_y
        $cam_axis.rotation_degrees.x = cam_rot_x
        $cam_axis/cam.look_at(Vector3.ZERO, Vector3.UP)

    if event is InputEventMouseMotion:
        if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            match button_status:
                BUTTON_LEFT:
                    cam_rot_y = cam_rot_y - event.relative.x
                    cam_rot_x = clamp(cam_rot_x - event.relative.y, -85, 85)
                BUTTON_MIDDLE:
                    $cam_axis/cam.h_offset -= event.relative.x
                    $cam_axis/cam.v_offset += event.relative.y

            $cam_axis/cam.translation = vct_camera_pos
            $cam_axis.rotation_degrees.y = cam_rot_y
            $cam_axis.rotation_degrees.x = cam_rot_x
            $cam_axis/cam.look_at(Vector3.ZERO, Vector3.UP)


func _process(_delta):

    if anim_player.current_animation.length() > 0:
        var value = anim_player.current_animation_position
        $ui/slider_anim.value = value
        $ui/lbl_sequence.text = "%3.3f / %3.3f" % [
            value,
            anim_player.current_animation_length
        ]


func _on_bvh_file_item_selected(index):

    var bvh_filename: String = $ui/bvh_file.get_item_text(index)
    var bvh_pathname: String = dict_pathname[bvh_filename]
    var anim: Animation
    var anim_seek: float = 0.0
    var playing: bool = false

    $BVHSpatial.bvh_load(bvh_pathname)
    if preview_node != null:
        $BVHSpatial.remove_child(preview_node)
        preview_node.queue_free()
        preview_node = null

    # -
    # $BVHSpatial.build_skeleton()
    # -
    preview_node = $BVHSpatial.build_preview()
    $BVHSpatial.add_child(preview_node)

    # Adjust
    if dict_adjust.size() == 0:
        dict_adjust.clear()
        $ui/list_adjust.clear()
        for joint in $BVHSpatial.ary_hierarchy:
            dict_adjust[joint.joint_name] = BVHSpatial.CAdjust.new(
                joint.joint_name,
                joint.joint_name
            )
            $ui/list_adjust.add_item(joint.joint_name)

    # Animation
    anim = $BVHSpatial.build_animation(
        anim_mode,
        anim_node,
        dict_adjust
    )
    anim.loop = $ui/chk_loop.pressed

    if reload:
        #anim_seek = $ui/slider_anim.value
        anim_seek = 0

    playing = anim_player.is_playing()

    $ui/slider_anim.max_value = anim.length
    $ui/lbl_motion_name.text = bvh_filename

    if anim_player.get_animation_list().size() > 0:
        anim_player.remove_animation("anim")

    anim_player.add_animation("anim", anim)

    if playing:
        anim_player.play("anim")
    else:
        anim_player.stop()
    $ui/btn_anim_player.pressed = playing

    $ui/slider_anim.value = anim_seek

    reload = false


func _on_slider_anim_value_changed(value):

    if anim_player.current_animation.length() > 0:
        anim_player.seek(value)


func _on_btn_anim_player_toggled(button_pressed):

    if button_pressed:
        if anim_player.get_animation_list().size() > 0:
            anim_player.play("anim")
    else:
        anim_player.stop()


func _on_btn_lighting_toggled(button_pressed):

    $BVHSpatial.mat_preview.flags_unshaded = (button_pressed != true)


func _on_btn_floor_toggled(button_pressed):

    $floor.visible = button_pressed


func _on_btn_shadow_toggled(button_pressed):

    $SpotLight.shadow_enabled = button_pressed


func _on_FileDialog_dir_selected(dir):

    dict_pathname.clear()
    $ui/bvh_file.clear()

    scan_file(dir, BVH_EXT)


func menu_to_idx(popup: PopupMenu) -> int:

    for idx in range(BVHSpatial.E_AXIS.AXIS_MAX):
        if popup.is_item_checked(idx):
            return idx
    return 0


# ----
func update_ui_adjust(adjust: BVHSpatial.CAdjust):

    $ui/adjust_x.value = adjust.vct_adjust_rot.x
    $ui/adjust_y.value = adjust.vct_adjust_rot.y
    $ui/adjust_z.value = adjust.vct_adjust_rot.z

    update_ui_adjust_axis(adjust, $ui/axis_x, "Xrotation")
    update_ui_adjust_axis(adjust, $ui/axis_y, "Yrotation")
    update_ui_adjust_axis(adjust, $ui/axis_z, "Zrotation")


func update_ui_adjust_axis(adjust: BVHSpatial.CAdjust, button: MenuButton, name: String):

    for idx in range(BVHSpatial.E_AXIS.AXIS_MAX):
        button.get_popup().set_item_checked(idx, false)
    button.get_popup().set_item_checked(adjust.get_axis(name), true)
    button.text = adjust.get_axis_name(name)


func _on_list_adjust_item_selected(index):

    var k: String = $ui/list_adjust.get_item_text(index)

    current_adjust = dict_adjust[k]

    update_ui_adjust(current_adjust)


func _on_adjust_x_value_changed(value: float):

    if current_adjust != null:
        current_adjust.vct_adjust_rot.x = value
        $timer_value_changed.start()

    $ui/adjust_x.hint_tooltip = "%d" % [value]


func _on_adjust_y_value_changed(value: float):

    if current_adjust != null:
        current_adjust.vct_adjust_rot.y = value
        $timer_value_changed.start()

    $ui/adjust_y.hint_tooltip = "%d" % [value]


func _on_adjust_z_value_changed(value: float):

    if current_adjust != null:
        current_adjust.vct_adjust_rot.z = value
        $timer_value_changed.start()

    $ui/adjust_z.hint_tooltip = "%d" % [value]


func _on_value_changed(_value: float):

    $BVHSpatial.cube_size = $ui/slider_cube_size.value
    $ui/slider_cube_size.hint_tooltip = "%d" % [$BVHSpatial.cube_size]
    $timer_value_changed.start()


func _on_slider_scale_value_changed(value):

    $BVHSpatial.position_scale = SCALE[int(min(4, max(0, value)))]
    $ui/slider_scale.hint_tooltip = "%3.3f" % [SCALE[int(min(4, max(0, value)))]]
    bvh_reload()


func _on_AnimationPlayer_animation_finished(_anim_name):
    
    $ui/btn_anim_player.pressed = false
    $ui/slider_anim.value = 0


func _on_chk_loop_toggled(_button_pressed):
    $timer_value_changed.start()


func _on_axis_x_changed(value):

    if current_adjust != null:
        current_adjust.dict_axis["Xrotation"] = value
        update_ui_adjust(current_adjust)
        $timer_value_changed.start()


func _on_axis_y_changed(value):

    if current_adjust != null:
        current_adjust.dict_axis["Yrotation"] = value
        update_ui_adjust(current_adjust)
        $timer_value_changed.start()
        

func _on_axis_z_changed(value):

    if current_adjust != null:
        current_adjust.dict_axis["Zrotation"] = value
        update_ui_adjust(current_adjust)
        $timer_value_changed.start()


func _on_btn_camera_reset_pressed():

    vct_camera_pos = Vector3(0, 0, DEFAULT_CAM_DISTANCE)
    cam_rot_x = DEFAULT_CAM_ROT_X
    cam_rot_y = DEFAULT_CAM_ROT_Y

    $cam_axis/cam.h_offset = DEFAULT_CAM_H_OFFSET
    $cam_axis/cam.v_offset = DEFAULT_CAM_V_OFFSET

    $cam_axis/cam.translation = vct_camera_pos
    $cam_axis.rotation_degrees.y = cam_rot_y
    $cam_axis.rotation_degrees.x = cam_rot_x
    $cam_axis/cam.look_at(Vector3.ZERO, Vector3.UP)


func _on_menu_file(id: int):

    match id:

        0:
            if $ui/FileDialog.current_dir == "/":
                $ui/FileDialog.current_dir = OS.get_data_dir()
            $ui/FileDialog.popup_centered()
            return
        2:
            $ui/menu_main/btn_File/AdjustFileDialog.mode = FileDialog.MODE_OPEN_FILE

        3:
            $ui/menu_main/btn_File/AdjustFileDialog.mode = FileDialog.MODE_SAVE_FILE

    $ui/menu_main/btn_File/AdjustFileDialog.clear_filters()
    $ui/menu_main/btn_File/AdjustFileDialog.add_filter("*.json;BVH Adjust File")
    if $ui/menu_main/btn_File/AdjustFileDialog.current_dir == "/":
        $ui/menu_main/btn_File/AdjustFileDialog.current_dir = OS.get_data_dir()
    $ui/menu_main/btn_File/AdjustFileDialog.popup_centered()


func _on_AdjustFileDialog_file_selected(path: String):

    match $ui/menu_main/btn_File/AdjustFileDialog.mode:

        FileDialog.MODE_OPEN_FILE:
            _import_adjust_file(path)

        FileDialog.MODE_SAVE_FILE:
            _export_adjust_file(path)


func _import_adjust_file(path: String):

    var wf: File = File.new()
    var json_result: JSONParseResult

    dict_adjust.clear()
    $ui/list_adjust.clear()

    wf.open(path, File.READ)

    json_result = JSON.parse(wf.get_as_text())
    if json_result.error == OK:
        for name in json_result.result.keys():
            var adjust: BVHSpatial.CAdjust = BVHSpatial.CAdjust.new(name, name)
            adjust.import_dict(json_result.result[name])
            dict_adjust[name] = adjust

    for name in dict_adjust.keys():
        $ui/list_adjust.add_item(name)

    wf.close()


func _export_adjust_file(path: String):

    var dict_export: Dictionary = {}
    var wf: File = File.new()
    
    for name in dict_adjust.keys():
        dict_export[name] = dict_adjust[name].export_dict()

    wf.open(path, File.WRITE)

    wf.store_string(JSON.print(dict_export, JSON_INDENT))

    wf.close()


func _on_timer_value_changed_timeout():

    bvh_reload()



