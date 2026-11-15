"""Switchyard — Godot `.import` ayar dosyalarını ilk kez yazar (varsa dokunmaz).

Neden: GLB'lerin içe aktarma betiği (malzeme eşlemesi) ve normal haritalarının
"normal map" sıkıştırması ilk içe aktarmada doğru olsun. Godot sonradan uid/hedef
alanlarını kendisi ekler; dosya zaten varsa yalnız eksik anahtar düzeltilir.

    python3 tools/blender/write_imports.py
"""

import glob
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

GLB_PARAMS = """nodes/root_type=""
nodes/root_name=""
nodes/apply_root_scale=true
nodes/root_scale=1.0
meshes/ensure_tangents=true
meshes/generate_lods=false
meshes/create_shadow_meshes=true
meshes/light_baking=0
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
import_script/path="res://assets/models/sy_post_import.gd"
_subresources={}
gltf/naming_version=1
gltf/embedded_image_handling=1
"""

TEX_PARAMS = """compress/mode={mode}
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""

# Kayıpsız kalması gereken küçük maske/gürültü dokuları
LOSSLESS = {"noise_rgba", "soft_shadow", "soft_blob"}


def res_path(p):
    return "res://" + os.path.relpath(p, ROOT).replace(os.sep, "/")


def write_glb_import(glb):
    imp = glb + ".import"
    if os.path.exists(imp):
        txt = open(imp).read()
        if "sy_post_import.gd" not in txt:
            if "import_script/path=" in txt:
                lines = [('import_script/path="res://assets/models/sy_post_import.gd"'
                          if ln.startswith("import_script/path=") else ln) for ln in txt.splitlines()]
                open(imp, "w").write("\n".join(lines) + "\n")
                print("  düzeltildi:", res_path(imp))
        return
    with open(imp, "w") as f:
        f.write('[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n')
        f.write(f'[deps]\n\nsource_file="{res_path(glb)}"\n\n[params]\n\n')
        f.write(GLB_PARAMS)
    print("  yazıldı:", res_path(imp))


def write_tex_import(png):
    imp = png + ".import"
    if os.path.exists(imp):
        return
    stem = os.path.splitext(os.path.basename(png))[0]
    normal = 1 if stem.endswith("_normal") else 2
    mode = 0 if stem in LOSSLESS else 2
    with open(imp, "w") as f:
        f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n')
        f.write(f'[deps]\n\nsource_file="{res_path(png)}"\n\n[params]\n\n')
        f.write(TEX_PARAMS.format(mode=mode, normal=normal))
    print("  yazıldı:", res_path(imp))


def main():
    for glb in sorted(glob.glob(os.path.join(ROOT, "assets", "models", "**", "*.glb"), recursive=True)):
        write_glb_import(glb)
    for png in sorted(glob.glob(os.path.join(ROOT, "assets", "textures", "*.png"))):
        write_tex_import(png)


if __name__ == "__main__":
    main()
