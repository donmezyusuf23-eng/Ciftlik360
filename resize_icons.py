import os
import sys
from PIL import Image

def generate_mipmaps(src_path):
    if not os.path.exists(src_path):
        print(f"Hata: {src_path} bulunamadı!")
        return False

    img = Image.open(src_path).convert("RGBA")

    sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }

    base_res = r"ciftlik360_app/android/app/src/main/res"

    for folder, size in sizes.items():
        out_dir = os.path.join(base_res, folder)
        os.makedirs(out_dir, exist_ok=True)
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        out_path = os.path.join(out_dir, "ic_launcher.png")
        resized.save(out_path, "PNG")
        print(f"Kaydedildi: {out_path} ({size}x{size})")

    # Also save as app logo inside Flutter assets if needed
    assets_dir = r"ciftlik360_app/assets"
    os.makedirs(assets_dir, exist_ok=True)
    img.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(assets_dir, "logo.png"), "PNG")
    print("Tüm ikonlar başarıyla üretildi!")
    return True

if __name__ == '__main__':
    src = sys.argv[1] if len(sys.argv) > 1 else 'farm_icon.png'
    generate_mipmaps(src)
