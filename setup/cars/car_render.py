import addon_utils, bpy, sys, os, math, mathutils
addon_utils.enable('Sollumz', default_set=True)
args = sys.argv[sys.argv.index('--') + 1:]
for o in list(bpy.data.objects): bpy.data.objects.remove(o)  # пустая сцена: без куба, камеры и лампы по умолчанию
src, out = args[0], args[1]
bpy.ops.sollumz.import_assets(directory=os.path.dirname(src), files=[{'name': os.path.basename(src)}], textures_mode='PACK')
# только высокий LOD, без стёкол-коллизий: прячем всё, что не меш
for o in bpy.data.objects:
    if o.type != 'MESH' or getattr(o, 'sollum_type', '') != 'sollumz_drawable_model': o.hide_render = True
body = [o for o in bpy.data.objects if o.type == 'MESH' and not o.hide_render and o.name.lower().startswith('bodyshell') and len(o.data.polygons) > 5000]
meshes = body or [o for o in bpy.data.objects if o.type == 'MESH' and not o.hide_render]
mn = mathutils.Vector((1e9,)*3); mx = mathutils.Vector((-1e9,)*3)
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ mathutils.Vector(c); mn = mathutils.Vector(map(min, mn, w)); mx = mathutils.Vector(map(max, mx, w))
ctr = (mn + mx) / 2; size = (mx - mn).length
sc = bpy.context.scene
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
d = size * 0.75
cam.location = ctr + mathutils.Vector((d * 0.8, -d * 0.9, d * 0.35))
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'SINGLE'
sc.display.shading.show_cavity = True; sc.display.shading.cavity_type = 'BOTH'
sc.render.resolution_x = 900; sc.render.resolution_y = 600
sc.render.filepath = out
cam.data.lens = 35
for o in bpy.data.objects:
    for m in getattr(o, 'modifiers', []):
        if m.type == 'ARMATURE': m.show_render = False; m.show_viewport = False
for o in bpy.data.objects:
    if o.type == 'MESH':
        print('KV mods', o.name, [(m.type, getattr(m,'object',None) and m.object.name) for m in o.modifiers], o.users_collection[0].name if o.users_collection else None, o.parent_type) if o.name.startswith('bodyshell') else None
print('KV dbg', tuple(round(x,2) for x in ctr), round(size,2), tuple(round(x,2) for x in cam.location), len([o for o in bpy.data.objects if o.type=='MESH' and not o.hide_render]), [c.name for c in sc.collection.children], [ (c.name, c.hide_render) for c in bpy.data.collections][:5], sc.view_layers[0].name)
bpy.ops.render.render(write_still=True)
# второй ракурс — крупно перед и салон через окно
cam.location = ctr + mathutils.Vector((size * 0.32, -size * 0.38, size * 0.2))
cam.rotation_euler = (ctr + mathutils.Vector((size*0.15, 0, 0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.render.filepath = out.replace('.png', '_close.png')
bpy.ops.render.render(write_still=True)
print('KV rendered', out)
