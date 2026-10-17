import bpy, sys, math, os, mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
MODEL_PATH = argv[0]
OUT_DIR = argv[1]

FRAME_SIZE = 512
DIRECTION_COUNT = 36
ORTHO_SCALE = 280  # calibrated so no rotation frame clips at FRAME_SIZE

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=MODEL_PATH)

# The rig below orbits the camera around world origin while the model
# stays fixed, so an off-center bounding box makes it swing through frame
# instead of turning in place. Recenter X/Y on the bbox center; set Z so
# the bbox's bottom sits at Z=0 ("ground level" for the shadow pass).
imported = [o for o in bpy.context.scene.objects if o.type == 'MESH']
min_co = mathutils.Vector((1e9, 1e9, 1e9))
max_co = mathutils.Vector((-1e9, -1e9, -1e9))
for o in imported:
    for v in o.bound_box:
        world = o.matrix_world @ mathutils.Vector(v)
        min_co.x = min(min_co.x, world.x)
        min_co.y = min(min_co.y, world.y)
        min_co.z = min(min_co.z, world.z)
        max_co.x = max(max_co.x, world.x)
        max_co.y = max(max_co.y, world.y)
        max_co.z = max(max_co.z, world.z)
offset = mathutils.Vector(((min_co.x + max_co.x) / 2, (min_co.y + max_co.y) / 2, min_co.z))
for o in imported:
    if o.parent is None:
        o.location -= offset

# Rig: empty at origin, camera + sun parented to it, rotate empty per frame.
bpy.ops.object.empty_add(location=(0, 0, 0))
rig = bpy.context.object
rig.name = "RotationRig"

bpy.ops.object.camera_add()
cam = bpy.context.object
cam.data.type = 'ORTHO'
cam.data.ortho_scale = ORTHO_SCALE
cam.location = (0, -500, 500)  # 45 degrees up, -Y looking toward +Y/+Z origin
cam.rotation_euler = (math.radians(45), 0, 0)
cam.parent = rig
bpy.context.scene.camera = cam

# Shadow-casting lights read as unwanted dirt/damage at sprite scale
# (e.g. the fuselage casting a dark patch near the tails). Two suns from
# complementary angles, neither casting shadows, shade the model via
# surface normals alone -- keeps the 3D form without hard shadow edges.
bpy.ops.object.light_add(type='SUN')
sun = bpy.context.object
sun.data.energy = 2.5
sun.data.use_shadow = False
sun.rotation_euler = (math.radians(45), 0, math.radians(135))
sun.parent = rig

bpy.ops.object.light_add(type='SUN')
fill = bpy.context.object
fill.data.energy = 1.2
fill.data.use_shadow = False
fill.rotation_euler = (math.radians(60), 0, math.radians(-45))
fill.parent = rig

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = FRAME_SIZE
scene.render.resolution_y = FRAME_SIZE
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(os.path.join(OUT_DIR, "shadow"), exist_ok=True)

def rig_angle(i):
    # Factorio's direction convention: frame 0 = north, increasing
    # clockwise (9=east, 18=south, 27=west).
    return (2 * math.pi * i / DIRECTION_COUNT) - (math.pi / 2)

for i in range(DIRECTION_COUNT):
    rig.rotation_euler = (0, 0, rig_angle(i))
    scene.render.filepath = os.path.join(OUT_DIR, f"frame_{i:02d}.png")
    bpy.ops.render.render(write_still=True)

# Dedicated icon render: southeast-facing (135 degrees clockwise from
# north), not one of the 36 rotation frames -- southeast falls between
# frame 13 (130deg) and frame 14 (140deg), neither of which is exact, so
# this renders the precise angle directly instead of reusing a frame.
rig.rotation_euler = (0, 0, math.radians(135) - math.radians(90))
scene.render.filepath = os.path.join(OUT_DIR, "icon_source.png")
bpy.ops.render.render(write_still=True)

# Shadow pass: flatten a duplicate of every mesh onto the ground plane and
# render that alone, unlit black, from the same rig -- a standard "fake
# drop shadow" technique that doesn't depend on getting Eevee's real
# shadow-catcher compositor setup right.
shadow_objs = []
for obj in list(bpy.context.scene.objects):
    if obj.type != 'MESH':
        continue
    dup = obj.copy()
    dup.data = obj.data.copy()
    dup.name = obj.name + "_shadow"
    bpy.context.collection.objects.link(dup)

    # Bake the full world transform into local space first -- the glTF
    # import's parent hierarchy means local Z doesn't necessarily line up
    # with world-up, so zeroing world-Z vertices directly (after clearing
    # the parent) is safe regardless of that hierarchy's orientation.
    world_matrix = obj.matrix_world.copy()
    dup.parent = None
    dup.matrix_world = world_matrix
    for o in bpy.context.selected_objects:
        o.select_set(False)
    dup.select_set(True)
    bpy.context.view_layer.objects.active = dup
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for v in dup.data.vertices:
        v.co.z = 0.0

    black_mat = bpy.data.materials.new(name=dup.name + "_mat")
    black_mat.use_nodes = True
    bsdf = black_mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0, 0, 0, 1)
        bsdf.inputs["Emission Strength"].default_value = 0
    dup.data.materials.clear()
    dup.data.materials.append(black_mat)
    shadow_objs.append(dup)

for obj in bpy.context.scene.objects:
    if obj.type == 'MESH' and obj not in shadow_objs:
        obj.hide_render = True

for i in range(DIRECTION_COUNT):
    rig.rotation_euler = (0, 0, rig_angle(i))
    scene.render.filepath = os.path.join(OUT_DIR, "shadow", f"frame_{i:02d}.png")
    bpy.ops.render.render(write_still=True)

print(f"RENDER_DONE frame_size={FRAME_SIZE} direction_count={DIRECTION_COUNT} ortho_scale={ORTHO_SCALE}")
