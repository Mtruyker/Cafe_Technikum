from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
BRANDING_DIR = ROOT / "assets" / "branding"
ANDROID_RES_DIR = ROOT / "android" / "app" / "src" / "main" / "res"
WINDOWS_ICON_PATH = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"


def _hex(color: str) -> tuple[int, int, int]:
    color = color.lstrip("#")
    return tuple(int(color[i : i + 2], 16) for i in (0, 2, 4))


def _gradient(size: int, start: str, end: str) -> Image.Image:
    start_rgb = _hex(start)
    end_rgb = _hex(end)
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    for y in range(size):
        t = y / (size - 1)
        row = (
            int(start_rgb[0] * (1 - t) + end_rgb[0] * t),
            int(start_rgb[1] * (1 - t) + end_rgb[1] * t),
            int(start_rgb[2] * (1 - t) + end_rgb[2] * t),
        )
        for x in range(size):
            pixels[x, y] = row
    return image


def _paste_rotated_bar(
    image: Image.Image,
    center: tuple[float, float],
    width: int,
    height: int,
    color: str,
    angle: float,
) -> None:
    bar = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(bar)
    draw.rounded_rectangle((0, 0, width, height), radius=height // 2, fill=color)
    rotated = bar.rotate(angle, expand=True, resample=Image.Resampling.BICUBIC)
    x = int(center[0] - rotated.width / 2)
    y = int(center[1] - rotated.height / 2)
    image.alpha_composite(rotated, (x, y))


def _draw_mobile_icon(size: int = 1024) -> Image.Image:
    icon = _gradient(size, "#FFE9CF", "#F9C991").convert("RGBA")
    draw = ImageDraw.Draw(icon)

    cx = cy = size // 2
    donut_outer = int(size * 0.33)
    donut_inner = int(size * 0.22)

    draw.ellipse(
        (cx - donut_outer, cy - donut_outer, cx + donut_outer, cy + donut_outer),
        fill="#C8570D",
    )
    draw.ellipse(
        (cx - donut_inner, cy - donut_inner, cx + donut_inner, cy + donut_inner),
        fill="#FFF7EC",
    )

    sprinkle_colors = ["#FFD15D", "#9EDB83", "#7CC8FF", "#FF8FA8"]
    sprinkle_points = [
        (0.34, 0.31, -24),
        (0.44, 0.28, 16),
        (0.56, 0.28, -12),
        (0.66, 0.33, 28),
        (0.69, 0.45, -8),
        (0.65, 0.56, 15),
        (0.57, 0.64, -28),
        (0.46, 0.67, 10),
        (0.36, 0.64, -14),
        (0.30, 0.55, 24),
        (0.28, 0.45, -6),
        (0.31, 0.35, 20),
    ]
    for index, (px, py, angle) in enumerate(sprinkle_points):
        _paste_rotated_bar(
            icon,
            (size * px, size * py),
            int(size * 0.052),
            int(size * 0.014),
            sprinkle_colors[index % len(sprinkle_colors)],
            angle,
        )

    cup_color = "#1F1D1A"
    top_y = int(size * 0.44)
    cup_left = int(size * 0.365)
    cup_right = int(size * 0.635)
    cup_bottom = int(size * 0.62)
    draw.rounded_rectangle(
        (int(size * 0.33), top_y, int(size * 0.67), top_y + int(size * 0.03)),
        radius=int(size * 0.015),
        fill=cup_color,
    )
    draw.rounded_rectangle(
        (cup_left, top_y + int(size * 0.014), cup_right, cup_bottom),
        radius=int(size * 0.03),
        fill=cup_color,
    )
    handle_rect = (
        int(size * 0.62),
        int(size * 0.49),
        int(size * 0.72),
        int(size * 0.63),
    )
    draw.rounded_rectangle(handle_rect, radius=int(size * 0.05), fill=cup_color)
    inner_handle = (
        int(size * 0.64),
        int(size * 0.51),
        int(size * 0.70),
        int(size * 0.61),
    )
    draw.rounded_rectangle(inner_handle, radius=int(size * 0.04), fill="#FFF7EC")

    steam_color = "#2D2A26"
    draw.line(
        [
            (int(size * 0.44), int(size * 0.39)),
            (int(size * 0.45), int(size * 0.35)),
            (int(size * 0.44), int(size * 0.31)),
        ],
        fill=steam_color,
        width=int(size * 0.014),
        joint="curve",
    )
    draw.line(
        [
            (int(size * 0.50), int(size * 0.38)),
            (int(size * 0.515), int(size * 0.33)),
            (int(size * 0.50), int(size * 0.28)),
        ],
        fill=steam_color,
        width=int(size * 0.014),
        joint="curve",
    )
    draw.line(
        [
            (int(size * 0.56), int(size * 0.39)),
            (int(size * 0.57), int(size * 0.35)),
            (int(size * 0.56), int(size * 0.31)),
        ],
        fill=steam_color,
        width=int(size * 0.014),
        joint="curve",
    )

    return icon


def _draw_admin_icon(size: int = 1024) -> Image.Image:
    icon = _gradient(size, "#EDF4EF", "#D2E2D8").convert("RGBA")
    draw = ImageDraw.Draw(icon)

    outer_shield = [
        (size * 0.5, size * 0.12),
        (size * 0.78, size * 0.23),
        (size * 0.78, size * 0.46),
        (size * 0.5, size * 0.88),
        (size * 0.22, size * 0.46),
        (size * 0.22, size * 0.23),
    ]
    inner_shield = [
        (size * 0.5, size * 0.17),
        (size * 0.73, size * 0.26),
        (size * 0.73, size * 0.46),
        (size * 0.5, size * 0.80),
        (size * 0.27, size * 0.46),
        (size * 0.27, size * 0.26),
    ]

    draw.polygon(outer_shield, fill="#214534")
    draw.polygon(inner_shield, fill="#F4FBF6")

    cx, cy = int(size * 0.5), int(size * 0.46)
    outer = int(size * 0.22)
    inner = int(size * 0.15)
    draw.ellipse((cx - outer, cy - outer, cx + outer, cy + outer), fill="#C8570D")
    draw.ellipse((cx - inner, cy - inner, cx + inner, cy + inner), fill="#FFF8EE")

    cup_color = "#223A2E"
    draw.rounded_rectangle(
        (int(size * 0.39), int(size * 0.42), int(size * 0.61), int(size * 0.44)),
        radius=int(size * 0.01),
        fill=cup_color,
    )
    draw.rounded_rectangle(
        (int(size * 0.415), int(size * 0.435), int(size * 0.585), int(size * 0.545)),
        radius=int(size * 0.02),
        fill=cup_color,
    )
    draw.rounded_rectangle(
        (int(size * 0.585), int(size * 0.455), int(size * 0.655), int(size * 0.55)),
        radius=int(size * 0.03),
        fill=cup_color,
    )
    draw.rounded_rectangle(
        (int(size * 0.602), int(size * 0.472), int(size * 0.642), int(size * 0.532)),
        radius=int(size * 0.02),
        fill="#F4FBF6",
    )

    steam_color = "#223A2E"
    draw.line(
        [
            (int(size * 0.46), int(size * 0.39)),
            (int(size * 0.47), int(size * 0.36)),
            (int(size * 0.46), int(size * 0.33)),
        ],
        fill=steam_color,
        width=int(size * 0.009),
    )
    draw.line(
        [
            (int(size * 0.50), int(size * 0.38)),
            (int(size * 0.51), int(size * 0.34)),
            (int(size * 0.50), int(size * 0.30)),
        ],
        fill=steam_color,
        width=int(size * 0.009),
    )
    draw.line(
        [
            (int(size * 0.54), int(size * 0.39)),
            (int(size * 0.55), int(size * 0.36)),
            (int(size * 0.54), int(size * 0.33)),
        ],
        fill=steam_color,
        width=int(size * 0.009),
    )

    lock_body = (
        int(size * 0.455),
        int(size * 0.66),
        int(size * 0.545),
        int(size * 0.74),
    )
    draw.rounded_rectangle(lock_body, radius=int(size * 0.015), fill="#214534")
    draw.arc(
        (
            int(size * 0.47),
            int(size * 0.60),
            int(size * 0.53),
            int(size * 0.68),
        ),
        start=180,
        end=360,
        fill="#214534",
        width=int(size * 0.012),
    )
    draw.ellipse(
        (
            int(size * 0.495),
            int(size * 0.695),
            int(size * 0.505),
            int(size * 0.705),
        ),
        fill="#D2E2D8",
    )

    return icon


def _save_png(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = image.resize((size, size), Image.Resampling.LANCZOS)
    out.save(path, format="PNG")


def generate() -> None:
    mobile_master = _draw_mobile_icon(1024)
    admin_master = _draw_admin_icon(1024)

    mobile_master_path = BRANDING_DIR / "techcafe_mobile_icon_1024.png"
    admin_master_path = BRANDING_DIR / "techcafe_admin_icon_1024.png"
    _save_png(mobile_master, mobile_master_path, 1024)
    _save_png(admin_master, admin_master_path, 1024)

    android_sizes = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    for relative, size in android_sizes.items():
        _save_png(mobile_master, ANDROID_RES_DIR / relative, size)

    WINDOWS_ICON_PATH.parent.mkdir(parents=True, exist_ok=True)
    admin_master.save(
        WINDOWS_ICON_PATH,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    print(f"Generated: {mobile_master_path}")
    print(f"Generated: {admin_master_path}")
    print("Updated Android launcher icons and Windows app icon.")


if __name__ == "__main__":
    generate()
