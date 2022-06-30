class_name BVHSpatialX
extends Spatial


const DEFAULT_CUBE_SIZE: int = 5
enum E_ANIMATION_MODE {SKELETON = 0, PREVIEW = 1}

var skel: Skeleton

var ary_pos: int = 0
var ary_channel: Array = []
var ary_motion: Array = []
var dict_order: Dictionary = {
    "Xrotation": Vector3.RIGHT,
    "Yrotation": Vector3.UP,
    "Zrotation": Vector3.BACK,
}
var mat_base: SpatialMaterial
var cube_size: int = DEFAULT_CUBE_SIZE

var frames: int = 0
var frame_time: float = 0.0


class CChannel:

    var name: String = ""
    var size: int = 0
    var ary_item: Array = []
    
    func _init(name: String, size: int, ary_item: PoolStringArray):
        self.name = name
        self.size = size
        for n in range(2, ary_item.size()):
            self.ary_item.append(ary_item[n])


func create_skin(bone: String, parent_bone: String, parent_node: Spatial, origin: Vector3) -> Spatial:

    skel.add_bone(bone)

    var idx: int = skel.find_bone(bone)
    var tform: Transform = Transform(Basis.IDENTITY, origin)

    skel.set_bone_rest(idx, tform)
    if parent_bone == "":
        skel.set_bone_parent(idx, -1)
    else:
        skel.set_bone_parent(idx, skel.find_bone(parent_bone))

    var node: CSGBox = CSGBox.new()

    node.name = bone
    node.width = cube_size
    node.height = cube_size
    node.depth = cube_size
    node.transform = tform
    node.material_override = mat_base
    parent_node.add_child(node)

    return node


func load_hierarchy(ary_line: Array, parent_bone: String, parent_node: Spatial):

    if ary_pos < ary_line.size():
        match ary_line[ary_pos][0]:

            "HIERARCHY":
                pass

            "ROOT", "JOINT":
                var bone: String = ary_line[ary_pos][1]
                var origin: Vector3 = Vector3(
                    ary_line[ary_pos + 2][1].to_float(),
                    ary_line[ary_pos + 2][2].to_float(),
                    ary_line[ary_pos + 2][3].to_float()
                )

                var node = create_skin(bone, parent_bone, parent_node, origin)

                ary_channel.append(
                    CChannel.new(
                        bone,
                        ary_line[ary_pos + 3][1].to_int(),
                        ary_line[ary_pos + 3]
                    )
                )

                ary_pos += 3
                load_hierarchy(ary_line, bone, node)

            "End":
                var bone: String = ary_line[ary_pos][1]

                ary_pos += 2
                load_hierarchy(ary_line, bone, parent_node)

            "}":
                return

            "MOTION":

                if ary_line[ary_pos + 1].size() == 1:
                    var re: RegEx = RegEx.new()
                    re.compile("^Frames:.*?([+-]?[0-9]+)$")
                    var result = re.search(ary_line[ary_pos + 1][0])
                    frames = result.get_string(1).to_int()

                if ary_line[ary_pos + 2].size() == 1:
                    var re: RegEx = RegEx.new()
                    re.compile("^Frame Time:.*?([+-]?[0-9]+.[0-9]+([eE][+-]?[0-9]+)?)$")
                    var result = re.search(ary_line[ary_pos + 2][0])
                    frame_time = result.get_string(1).to_float()

                ary_pos += 3

                assert(frames <= (ary_line.size() - ary_pos))
                assert(frame_time > 0.0)

                if frames <= (ary_line.size() - ary_pos):
                    if frame_time > 0.0:
                        for ary_data in ary_line.slice(ary_pos, ary_pos + (frames - 1)):
                            if ary_data.size() > 0:
                                var _ary = []
                                for v in ary_data:
                                    _ary.append(v.to_float())
                                ary_motion.append(_ary)

                return

    ary_pos += 1
    load_hierarchy(ary_line, parent_bone, parent_node)


func load_bvh(pathname: String, target_skel: Skeleton, preview_node: Spatial):

    skel = target_skel
    
    var rf = File.new()
    rf.open(pathname, File.READ)

    var ary_line: Array = []
    for line in rf.get_as_text().split("\n"):
        if line.begins_with("Frames:"):
            ary_line.append([line])
        elif line.begins_with("Frame Time:"):
            ary_line.append([line])
        else:
            ary_line.append(String(line).strip_edges().split(" "))

    ary_pos = 0
    ary_channel.clear()
    ary_motion.clear()

    skel.clear_bones()

    for item in preview_node.get_children():
        preview_node.remove_child(item)
        item.queue_free()

    load_hierarchy(ary_line, "", preview_node)


func create_bone_name(idx: int) -> String:
    
    if skel.get_bone_parent(idx) == -1:
        return skel.get_bone_name(idx)
    else:
        return create_bone_name(skel.get_bone_parent(idx)) + "/" + skel.get_bone_name(idx)


func get_animation(path: NodePath, e_mode: int, dict_adjust: Dictionary) -> Animation:

    var anim: Animation = Animation.new()
    var ftime: float = 0.0

    for ch in ary_channel:
        match e_mode:
            E_ANIMATION_MODE.SKELETON:
                var track_index = anim.add_track(Animation.TYPE_TRANSFORM)
                var track_path = ch.name

                if ch.name in dict_adjust:
                    track_path = dict_adjust[ch.name].alias
                    # print("alias ", ch.name, ">", track_path)

                anim.track_set_path(
                    track_index,
                    "%s:%s" % [path, track_path]
                )
            E_ANIMATION_MODE.PREVIEW:
                var track_index = anim.add_track(Animation.TYPE_VALUE)
                var track_path = create_bone_name(skel.find_bone(ch.name))
                anim.track_set_path(
                    track_index,
                    "%s/%s:transform" % [path, track_path]
                )


    for item in ary_motion:
        var track_index: int = 0
        var idx: int = 0

        for ch in ary_channel:
            var n: int = 0
            var ary_rot_b: Array = []
            var ary_rot_q: Array = []
            var quat: Quat = Quat.IDENTITY
            var tform: Transform = Transform(Basis.IDENTITY)
            var vct_adjust: Vector3 = Vector3.ZERO
            var vct_direction: Vector3 = Vector3.ONE
            
            if ch.name in dict_adjust:
                vct_adjust = dict_adjust[ch.name].vct_adjust
                vct_direction = dict_adjust[ch.name].vct_direction

            for name in ch.ary_item:
                match name:
                    "Xposition":
                        tform.origin.x = item[n + idx]
                        pass
                    "Yposition":
                        tform.origin.y = item[n + idx]
                        pass
                    "Zposition":
                        tform.origin.z = item[n + idx]
                        pass
                    "Xrotation":
                        var vct_order: Vector3 = dict_order[name]
                        ary_rot_b.append(Basis(vct_order, deg2rad(item[n + idx])))
                        ary_rot_q.append(
                            Quat(vct_order, deg2rad(item[n + idx])) * Quat(vct_order, vct_adjust.x)
                        )
                    "Yrotation":
                        var vct_order: Vector3 = dict_order[name]
                        ary_rot_b.append(Basis(vct_order, deg2rad(item[n + idx])))
                        ary_rot_q.append(
                            Quat(vct_order, deg2rad(item[n + idx] * vct_direction.y)) * Quat(vct_order, vct_adjust.y)
                        )
                    "Zrotation":
                        var vct_order: Vector3 = dict_order[name]
                        ary_rot_b.append(Basis(vct_order, deg2rad(item[n + idx])))
                        ary_rot_q.append(
                            Quat(vct_order, deg2rad(item[n + idx])) * Quat(vct_order, vct_adjust.z)
                        )
                n += 1

            for rot in ary_rot_b:
                tform.basis *= rot

            for rot in ary_rot_q:
                quat *= rot
    
            match e_mode:
                E_ANIMATION_MODE.SKELETON:
                    anim.transform_track_insert_key(track_index, ftime, tform.origin * 0.001, quat, Vector3.ONE)
                E_ANIMATION_MODE.PREVIEW:
                    anim.track_insert_key(track_index, ftime, tform)

            track_index += 1
            idx += ch.size

        ftime += frame_time

    anim.loop = true
    anim.length = ftime

    return anim


func set_cube_size(size: int):

    cube_size = size


func bvh_load():
    pass


func bvh_save():
    pass


func _ready():
    
    mat_base = SpatialMaterial.new()
    mat_base.flags_do_not_receive_shadows = true    
    
