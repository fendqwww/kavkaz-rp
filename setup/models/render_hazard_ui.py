"""KAVKAZ RP: картинки пульта «Хазард 7007» для окна на экране (kavkaz_sgu/html/ui) — из той же модели, что стоит в салоне.
blender -b setup/models/hazard/kv_hazard7007.blend -P setup/models/render_hazard_ui.py -- <папка вывода>
выход: base.png (корпус с кнопками, без ручек), knob_sel.png и knob_vol.png (ручки отдельно, квадрат вокруг оси —
крутятся в CSS), led.png (горящий светодиод), ui.json (где что лежит на base.png, в процентах).
вид строго спереди, ортографический: поворот ручки в CSS = поворот вокруг её оси в 3D (по часовой — как в салоне).
"""
import json
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

OUT = os.path.abspath(sys.argv[sys.argv.index('--') + 1])
os.makedirs(OUT, exist_ok=True)
scene = bpy.context.scene

W, H = 1040, 560                 # кадр base.png, px
VIEW_W = 0.212                   # ширина кадра в метрах (корпус с ушками 0.208)
scene.render.engine = 'CYCLES'
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.cycles.device = 'CPU'
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'Standard'

cam = bpy.data.objects['cam']
cam.location = (0.0, -0.6, 0.0)
cam.rotation_euler = (1.5707963, 0.0, 0.0)  # смотрит в +Y, на лицо пульта
cam.data.type = 'ORTHO'
cam.data.ortho_scale = VIEW_W
cam.data.shift_x = cam.data.shift_y = 0.0
scene.camera = cam

PARTS = ['kv_hazard7007', 'kv_hazard_knob_vol', 'kv_hazard_knob_sel', 'kv_hazard_btn_pa', 'kv_hazard_btn_horn',
         'kv_hazard_led_l1', 'kv_hazard_led_l2']
obj = {n: bpy.data.objects[n] for n in PARTS}


def show(names):
    for n, o in obj.items():
        o.hide_render = n not in names


def render(name, w, h, border=None):
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.resolution_percentage = 100
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


def px(p):
    """точка мира → проценты кадра base.png (0..100, от левого верхнего угла)"""
    c = world_to_camera_view(scene, cam, Vector(p))
    return [round(c.x * 100, 3), round((1 - c.y) * 100, 3)]


scene.render.resolution_x, scene.render.resolution_y = W, H
layout = {'W': W, 'H': H}
for n in PARTS[1:]:
    layout[n] = px(obj[n].matrix_world.translation)

# 1) корпус с кнопками, светодиоды не горят, без ручек
show(['kv_hazard7007', 'kv_hazard_btn_pa', 'kv_hazard_btn_horn'])
render('base.png', W, H)

# 2) ручки: та же камера, кадр — квадрат вокруг оси ручки (сдвиг камеры), чтобы CSS крутил картинку вокруг центра
for n, size_m in (('kv_hazard_knob_sel', 0.044), ('kv_hazard_knob_vol', 0.032)):
    loc = obj[n].matrix_world.translation
    cam.data.ortho_scale = size_m
    cam.location = (loc.x, -0.6, loc.z)
    show([n])
    side = round(size_m / VIEW_W * W)
    render(n.replace('kv_hazard_', '') + '.png', side, side)
    layout[n + '_size'] = round(size_m / VIEW_W * 100, 3)  # ширина квадрата в % ширины base.png
cam.data.ortho_scale = VIEW_W
cam.location = (0.0, -0.6, 0.0)

json.dump(layout, open(os.path.join(OUT, 'ui.json'), 'w'), indent=1)
print('KAVKAZ готово', layout)
