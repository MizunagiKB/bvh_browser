class_name BVHSpatial
extends Spatial


const DEFAULT_CUBE_SIZE: int = 5
const DEFAULT_DICT_ORDER: Dictionary = {
    "Xrotation": Vector3.RIGHT,
    "Yrotation": Vector3.UP,
    "Zrotation": Vector3.BACK,
}
const ary_axis_name: Array = [
    "NONE",
    "LEFT", "RIGHT", "UP", "DOWN", "FORWARD", "BACK",
    "MAX"]

enum E_AXIS {
    AXIS_NONE = 0,
    AXIS_LEFT = 1, AXIS_RIGHT = 2, AXIS_UP = 3, AXIS_DOWN = 4, AXIS_FORWARD = 5, AXIS_BACK = 6,
    AXIS_MAX = 7}

enum E_ANIMATION_MODE {
    MODE_SKELETON = 0, MODE_PREVIEW = 1}

enum E_CHANNEL {
    E_CHANNEL_POS = 0x01,
    E_CHANNEL_ROT = 0x02,
    E_CHANNEL_ALL = 0x03
}

var read_pos: int = 0
var ary_hierarchy: Array = []
var ary_motion: Array = []
var frames: int = 0
var frame_time: float = 0.0


var cube_size: int = DEFAULT_CUBE_SIZE
var position_scale: float = 1.0
var mat_preview: SpatialMaterial


class CJoint:

    var joint_name: String = ""
    var vct_offset: Vector3 = Vector3.ZERO
    var channel_size: int = 0
    var ary_channel: Array = []
    var e_channel: int = 0
    var parent_joint: CJoint = null
    var ary_child: Array = []

    func _init(_joint_name: String, _vct_offset: Vector3, _channel_size: int, _ary_channel: PoolStringArray):
        self.joint_name = _joint_name
        self.vct_offset = _vct_offset
        self.channel_size = _channel_size

        for n in range(2, 2 + self.channel_size):
            if String(_ary_channel[n]).find("position") != -1: self.e_channel |= E_CHANNEL.E_CHANNEL_POS
            if String(_ary_channel[n]).find("rotation") != -1: self.e_channel |= E_CHANNEL.E_CHANNEL_ROT
            self.ary_channel.append(_ary_channel[n])

    func export_dict() -> Dictionary:
        var ary_child_item: Array = []

        for child_joint in self.ary_child:
            ary_child_item.append(child_joint.export_dict())

        return {
            "joint_name": self.joint_name,
            "vct_offset": {"x": self.vct_offset.x, "y": self.vct_offset.y, "z": self.vct_offset.z},
            "channel_size": self.channel_size,
            "ary_channel": self.ary_channel,
            "ary_child": ary_child_item
        }


class CAdjust:

    var joint_name: String = ""
    var alias_name: String = ""
    var vct_adjust_rot: Vector3 = Vector3.ZERO
    var dict_axis: Dictionary = {
        "Xrotation": E_AXIS.AXIS_RIGHT,
        "Yrotation": E_AXIS.AXIS_UP,
        "Zrotation": E_AXIS.AXIS_BACK,
    }
    
    
    func _init(_joint_name: String, _alias_name: String):

        self.joint_name = _joint_name
        self.alias_name = _alias_name


    func get_axis(name: String) -> int:
        return self.dict_axis[name]


    func get_axis_name(name: String) -> String:
        return ary_axis_name[self.get_axis(name)]


    func is_axis_enable(name: String) -> bool:
        if self.dict_axis[name] in [E_AXIS.AXIS_NONE, E_AXIS.AXIS_MAX]:
            return false
        else:
            return true


    func get_axis_vector(name: String) -> Vector3:
        
        assert(self.is_axis_enable(name))

        #if self.dict_axis[name] == E_AXIS.AXIS_LEFT:
        #    return Vector3.LEFT

        match self.dict_axis[name]:
            E_AXIS.AXIS_LEFT:
                return Vector3.LEFT
            E_AXIS.AXIS_RIGHT:
                return Vector3.RIGHT
            E_AXIS.AXIS_UP:
                return Vector3.UP
            E_AXIS.AXIS_DOWN:
                return Vector3.DOWN
            E_AXIS.AXIS_FORWARD:
                return Vector3.FORWARD
            E_AXIS.AXIS_BACK:
                return Vector3.BACK

        print([typeof(self.dict_axis[name]), typeof(E_AXIS.AXIS_LEFT), typeof("1"), typeof(1), typeof(1.0)])
        return Vector3.INF


    func import_dict(dict_data: Dictionary):
        
        self.joint_name = dict_data["joint_name"]
        self.alias_name = dict_data["alias_name"]
        self.vct_adjust_rot = Vector3(
            dict_data["vct_adjust_rot"]["x"],
            dict_data["vct_adjust_rot"]["y"],
            dict_data["vct_adjust_rot"]["z"]
        )
        self.dict_axis = {
            "Xrotation": ary_axis_name.find(dict_data["dict_axis"]["Xrotation"]),
            "Yrotation": ary_axis_name.find(dict_data["dict_axis"]["Yrotation"]),
            "Zrotation": ary_axis_name.find(dict_data["dict_axis"]["Zrotation"]),
        }


    func export_dict() -> Dictionary:

        return {
            "joint_name": self.joint_name,
            "alias_name": self.alias_name,
            "vct_adjust_rot": {
                "x": self.vct_adjust_rot.x,
                "y": self.vct_adjust_rot.y,
                "z": self.vct_adjust_rot.z
            },
            "dict_axis": {
                "Xrotation": self.get_axis_name("Xrotation"),
                "Yrotation": self.get_axis_name("Yrotation"),
                "Zrotation": self.get_axis_name("Zrotation")
            }
        }


func load_hierarchy(ary_line: Array, parent_joint: CJoint):

    if read_pos < ary_line.size():
        match ary_line[read_pos][0]:

            "HIERARCHY":
                pass

            "ROOT", "JOINT":
                var joint_name: String = ary_line[read_pos][1]
                var vct_offset: Vector3 = Vector3(
                    ary_line[read_pos + 2][1].to_float(),
                    ary_line[read_pos + 2][2].to_float(),
                    ary_line[read_pos + 2][3].to_float()
                )
                var joint: CJoint = CJoint.new(
                    joint_name,
                    vct_offset * position_scale,
                    ary_line[read_pos + 3][1].to_int(),
                    ary_line[read_pos + 3]
                )

                if parent_joint != null:
                    parent_joint.ary_child.append(joint)
                joint.parent_joint = parent_joint

                ary_hierarchy.append(joint)

                read_pos += 3
                # print(joint_name)
                load_hierarchy(ary_line, joint)                

            "End":
                read_pos += 2
                # print(joint_name)
                load_hierarchy(ary_line, parent_joint)

            "}":
                return

            "MOTION":
                var re: RegEx = RegEx.new()
                var re_result: RegExMatch

                re.compile("^Frames:.*?([+-]?[0-9]+)$")
                re_result = re.search(ary_line[read_pos + 1][0])
                if re_result:
                    frames = re_result.get_string(1).to_int()
                else:
                    return

                re.compile("^Frame Time:.*?([+-]?[0-9]+.[0-9]+([eE][+-]?[0-9]+)?)$")
                re_result = re.search(ary_line[read_pos + 2][0])
                if re_result:
                    frame_time = re_result.get_string(1).to_float()
                else:
                    return

                read_pos += 3

                # assert(frames <= (ary_line.size() - read_pos))
                # assert(frame_time > 0.0)

                if frames <= (ary_line.size() - read_pos):
                    for ary_param in ary_line.slice(read_pos, read_pos + (frames - 1)):
                        if ary_param.size() > 0:
                            var ary_work: Array = []
                            for v in ary_param:
                                ary_work.append(v.to_float())
                            ary_motion.append(ary_work)
                return

    read_pos += 1
    load_hierarchy(ary_line, parent_joint)


func create_joint_path_name(joint: CJoint, dict_adjust: Dictionary) -> String:

    var joint_name: String = joint.joint_name

    if joint.joint_name in dict_adjust:
        joint_name = dict_adjust[joint.joint_name].alias_name

    if joint.parent_joint == null:
        return joint_name
    else:
        return "%s/%s" % [create_joint_path_name(joint.parent_joint, dict_adjust), joint_name]


func _make_position(_e_mode: int):
    pass


func _make_rotation(e_mode: int, vct_axis: Vector3, value: float, ary_rot: Array):

    match e_mode:
        E_ANIMATION_MODE.MODE_SKELETON:
            ary_rot.append(
                Quat(vct_axis, deg2rad(value))
            )
        E_ANIMATION_MODE.MODE_PREVIEW:
            ary_rot.append(Basis(vct_axis, deg2rad(value)))
        _:
            assert(false)


func build_animation(e_mode: int, path: String, dict_adjust: Dictionary) -> Animation:

    var anim: Animation = Animation.new()
    var current_ftime: float = 0.0

    # create_track
    for _joint in ary_hierarchy:
        
        var joint: CJoint = _joint
        
        match e_mode:

            E_ANIMATION_MODE.MODE_SKELETON:
                var track_index = anim.add_track(Animation.TYPE_TRANSFORM)
                var track_path = joint.joint_name

                if joint.joint_name in dict_adjust:
                    track_path = dict_adjust[joint.joint_name].alias_name

                anim.track_set_path(
                    track_index,
                    "%s:%s" % [path, track_path]
                )

            E_ANIMATION_MODE.MODE_PREVIEW:
                var track_index = anim.add_track(Animation.TYPE_VALUE)
                var track_path = create_joint_path_name(joint, dict_adjust)

                anim.track_set_path(
                    track_index,
                    "%s/%s:transform" % [path, track_path]
                )

    # create_track_data
    for motion in ary_motion:

        var track_index: int = 0
        var channel_offset: int = 0

        for _joint in ary_hierarchy:
            
            var joint: CJoint = _joint
            var adjust: CAdjust

            var n: int = 0
            var ary_rot: Array = []
            var quat: Quat = Quat.IDENTITY
            var tform: Transform = Transform(Basis.IDENTITY)
            
            if joint.joint_name in dict_adjust:
                adjust = dict_adjust[joint.joint_name]

            for name in joint.ary_channel:

                match name:

                    "Xposition":
                        tform.origin.x = motion[channel_offset + n] * position_scale
                    "Yposition":
                        tform.origin.y = motion[channel_offset + n] * position_scale
                    "Zposition":
                        tform.origin.z = motion[channel_offset + n] * position_scale

                    "Xrotation", "Yrotation", "Zrotation":
                        if adjust is CAdjust:
                            if adjust.is_axis_enable(name):

                                var adjust_value: float = 0.0
                                match name:
                                    "Xrotation": adjust_value = adjust.vct_adjust_rot.x
                                    "Yrotation": adjust_value = adjust.vct_adjust_rot.y
                                    "Zrotation": adjust_value = adjust.vct_adjust_rot.z

                                _make_rotation(
                                    e_mode,
                                    adjust.get_axis_vector(name),
                                    motion[channel_offset + n] + adjust_value,
                                    ary_rot
                                )
                        else:
                            _make_rotation(
                                e_mode,
                                DEFAULT_DICT_ORDER[name],
                                motion[channel_offset + n],
                                ary_rot
                            )

                n += 1
    
            match e_mode:
                E_ANIMATION_MODE.MODE_SKELETON:
                    for rot in ary_rot:
                        quat *= rot
                    anim.transform_track_insert_key(track_index, current_ftime, tform.origin, quat, Vector3.ONE)
                E_ANIMATION_MODE.MODE_PREVIEW:
                    for rot in ary_rot:
                        tform.basis *= rot
                    if joint.e_channel == E_CHANNEL.E_CHANNEL_ROT:
                        tform.origin = joint.vct_offset

                    anim.track_insert_key(track_index, current_ftime, tform)

            track_index += 1
            channel_offset += joint.channel_size

        current_ftime += frame_time

    anim.length = current_ftime

    return anim
    

func _build_preivew_node(parent_node: Spatial, joint: CJoint) -> Spatial:

    var node: CSGBox = CSGBox.new()

    node.name = joint.joint_name
    node.width = cube_size
    node.height = cube_size
    node.depth = cube_size
    node.transform = Transform(Basis.IDENTITY, joint.vct_offset)
    node.material = mat_preview
    
    if parent_node != null:
        parent_node.add_child(node)

    for child_joint in joint.ary_child:
        _build_preivew_node(node, child_joint)

    return node


func build_preview() -> Spatial:

    if ary_hierarchy.size() > 0:
        return _build_preivew_node(null, ary_hierarchy[0])
    else:
        return null


func _build_skeleton_bone(skel: Skeleton, joint: CJoint):

    skel.add_bone(joint.joint_name)

    var idx: int = skel.find_bone(joint.joint_name)

    skel.set_bone_rest(idx, Transform(Basis.IDENTITY, joint.vct_offset))

    if joint.parent_joint == null:
        skel.set_bone_parent(idx, -1)
    else:
        skel.set_bone_parent(idx, skel.find_bone(joint.parent_joint.joint_name))
    

    for child_joint in joint.ary_child:
        _build_skeleton_bone(skel, child_joint)


func build_skeleton() -> Skeleton:

    if ary_hierarchy.size() > 0:
        var skel: Skeleton = Skeleton.new()
        _build_skeleton_bone(skel, ary_hierarchy[0])
        return skel
    else:
        return null


func bvh_load(pathname: String):

    var rf = File.new()
    var ary_line: Array = []

    read_pos = 0
    ary_hierarchy.clear()
    ary_motion.clear()
    frames = 0
    frame_time = 0.0

    rf.open(pathname, File.READ)

    for line in rf.get_as_text().split("\n"):
        if line.begins_with("Frames:"):
            ary_line.append([line])
        elif line.begins_with("Frame Time:"):
            ary_line.append([line])
        else:
            var ary_data: Array = []
            for v in String(line).strip_edges().split(" "):
                if String(v).length() > 0:
                    ary_data.append(v)
            ary_line.append(ary_data)

    load_hierarchy(ary_line, null)


func dict_export() -> Dictionary:

    return ary_hierarchy[0].export_dict()


func _ready():
    
    mat_preview = SpatialMaterial.new()
