#!/usr/bin/env python3
"""Render an original, unofficial Retti product-motion concept.

The piece is deliberately built from primitives and public product language so the
entire edit is reproducible and reviewable. It is demonstration work, not a client
commission, endorsement, or performance claim.
"""

from __future__ import annotations

import math
import subprocess
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source" / "retti-avatar.png"
OUTPUT = ROOT / "retti-product-motion-spec.mp4"
SILENT_VIDEO = ROOT / ".retti-product-motion-spec-video.mp4"
AUDIO = ROOT / ".retti-product-motion-spec-audio.wav"
CONTACT_SHEET = ROOT / "contact-sheet.jpg"
COVER = ROOT / "cover.png"

WIDTH, HEIGHT = 1920, 1080
FPS = 30
DURATION = 17.0
FRAMES = int(FPS * DURATION)
SAMPLE_RATE = 48_000

FONT_REGULAR = Path("/System/Library/Fonts/Supplemental/Arial.ttf")
FONT_BOLD = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")

INK = (241, 247, 255)
MUTED = (150, 169, 196)
BLUE = (73, 139, 255)
CYAN = (69, 222, 255)
RED = (255, 84, 112)
GREEN = (72, 226, 167)
AMBER = (255, 191, 86)
CARD = (13, 22, 39)
CARD_ALT = (18, 30, 51)
STROKE = (46, 72, 112)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_BOLD if bold else FONT_REGULAR
    return ImageFont.truetype(str(path), size=size)


FONTS = {
    "hero": font(120, True),
    "headline": font(90, True),
    "subhead": font(46, True),
    "body": font(38),
    "body_bold": font(38, True),
    "small": font(27),
    "small_bold": font(27, True),
    "micro": font(22, True),
    "metric": font(64, True),
}


def clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def ease_out(value: float) -> float:
    value = clamp(value)
    return 1.0 - (1.0 - value) ** 3


def ease_in_out(value: float) -> float:
    value = clamp(value)
    return value * value * (3.0 - 2.0 * value)


def scene_alpha(t: float, start: float, end: float, fade: float = 0.42) -> float:
    return min(ease_out((t - start) / fade), ease_out((end - t) / fade))


def with_alpha(color: tuple[int, int, int], alpha: int) -> tuple[int, int, int, int]:
    return (*color, max(0, min(255, alpha)))


def composite_scene(frame: Image.Image, scene: Image.Image, opacity: float) -> None:
    opacity = clamp(opacity)
    if opacity < 0.999:
        channel = scene.getchannel("A").point(lambda p: int(p * opacity))
        scene.putalpha(channel)
    frame.alpha_composite(scene)


def fit_text(draw: ImageDraw.ImageDraw, text: str, max_width: int, start_size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    size = start_size
    while size > 20:
        candidate = font(size, bold)
        if draw.textbbox((0, 0), text, font=candidate)[2] <= max_width:
            return candidate
        size -= 2
    return font(20, bold)


def round_card(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int = 34, fill: tuple[int, int, int] = CARD, outline: tuple[int, int, int] = STROKE, width: int = 2) -> None:
    x1, y1, x2, y2 = box
    draw.rounded_rectangle((x1 + 10, y1 + 14, x2 + 10, y2 + 14), radius=radius, fill=(0, 0, 0, 90))
    draw.rounded_rectangle(box, radius=radius, fill=(*fill, 245), outline=(*outline, 180), width=width)


def pill(draw: ImageDraw.ImageDraw, x: int, y: int, text: str, color: tuple[int, int, int], width: int | None = None) -> int:
    text_box = draw.textbbox((0, 0), text, font=FONTS["micro"])
    actual_width = width or (text_box[2] + 46)
    draw.rounded_rectangle((x, y, x + actual_width, y + 44), radius=22, fill=with_alpha(color, 30), outline=with_alpha(color, 150), width=2)
    draw.text((x + 23, y + 11), text, font=FONTS["micro"], fill=with_alpha(color, 255))
    return actual_width


def draw_base() -> Image.Image:
    yy, xx = np.mgrid[0:HEIGHT, 0:WIDTH]
    base = np.zeros((HEIGHT, WIDTH, 3), dtype=np.float32)
    base[:] = np.array((4, 8, 17), dtype=np.float32)

    for cx, cy, radius, color, strength in (
        (1450, 140, 950, np.array(BLUE), 0.16),
        (200, 1020, 850, np.array(CYAN), 0.08),
    ):
        distance = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        weight = np.clip(1.0 - distance / radius, 0.0, 1.0) ** 2
        base += weight[..., None] * color * strength

    base = np.clip(base, 0, 255).astype(np.uint8)
    image = Image.fromarray(base, "RGB").convert("RGBA")
    draw = ImageDraw.Draw(image, "RGBA")
    for x in range(0, WIDTH, 96):
        draw.line((x, 0, x, HEIGHT), fill=(110, 145, 200, 12), width=1)
    for y in range(0, HEIGHT, 96):
        draw.line((0, y, WIDTH, y), fill=(110, 145, 200, 10), width=1)
    draw.rectangle((0, 0, WIDTH, HEIGHT), outline=(111, 170, 255, 22), width=3)
    return image


BASE = draw_base()
AVATAR = Image.open(SOURCE).convert("RGBA")


def draw_brand_bug(frame: Image.Image, t: float) -> None:
    if t < 0.3:
        return
    layer = Image.new("RGBA", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(layer, "RGBA")
    opacity = ease_out((t - 0.3) / 0.5)
    avatar = AVATAR.resize((58, 58), Image.Resampling.LANCZOS)
    layer.alpha_composite(avatar, (58, 44))
    draw.text((132, 54), "RETTI", font=FONTS["small_bold"], fill=INK)
    draw.text((250, 58), "PRODUCT MOTION SPEC", font=FONTS["micro"], fill=MUTED)
    draw.rounded_rectangle((1535, 49, 1855, 91), radius=21, fill=(15, 27, 48, 210), outline=(66, 92, 132, 180), width=2)
    draw.text((1561, 59), "UNOFFICIAL CONCEPT", font=FONTS["micro"], fill=(184, 199, 222))
    composite_scene(frame, layer, opacity)


def draw_scene_one(frame: Image.Image, t: float) -> None:
    alpha = scene_alpha(t, 0.0, 3.15)
    if alpha <= 0:
        return
    scene = Image.new("RGBA", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(scene, "RGBA")

    p1 = ease_out((t - 0.08) / 0.75)
    p2 = ease_out((t - 0.78) / 0.75)
    x = int(140 + 65 * (1.0 - p1))
    draw.text((x, 235), "3 WEEKS TO EDIT.", font=FONTS["hero"], fill=with_alpha(INK, int(255 * p1)))
    draw.text((140, 390 + int(35 * (1.0 - p2))), "3 SECONDS TO LOSE THEM.", font=fit_text(draw, "3 SECONDS TO LOSE THEM.", 1640, 120), fill=with_alpha(RED, int(255 * p2)))
    draw.text((144, 548), "The launch story starts at the exact second attention breaks.", font=FONTS["body"], fill=with_alpha(MUTED, int(255 * p2)))

    graph_box = (144, 688, 1776, 930)
    draw.rounded_rectangle(graph_box, radius=30, fill=(10, 18, 33, 225), outline=(44, 70, 109, 170), width=2)
    for index in range(1, 5):
        gy = graph_box[1] + index * 42
        draw.line((graph_box[0] + 35, gy, graph_box[2] - 35, gy), fill=(98, 123, 162, 28), width=2)

    progress = ease_in_out((t - 1.2) / 1.25)
    points: list[tuple[int, int]] = []
    count = max(2, int(130 * progress))
    for index in range(count):
        u = index / 129
        gx = graph_box[0] + 45 + int(u * (graph_box[2] - graph_box[0] - 90))
        drop = 23 + 128 / (1 + math.exp(-(u - 0.29) * 34))
        texture = 8 * math.sin(u * 18) + 5 * math.sin(u * 41)
        gy = graph_box[1] + 45 + int(drop + texture)
        points.append((gx, gy))
    if len(points) > 1:
        draw.line(points, fill=with_alpha(CYAN, 95), width=18, joint="curve")
        draw.line(points, fill=CYAN, width=6, joint="curve")

    marker_x = graph_box[0] + 45 + int(0.29 * (graph_box[2] - graph_box[0] - 90))
    draw.line((marker_x, graph_box[1] + 24, marker_x, graph_box[3] - 28), fill=with_alpha(RED, int(220 * progress)), width=3)
    if progress > 0.72:
        draw.rounded_rectangle((marker_x - 54, graph_box[1] + 20, marker_x + 78, graph_box[1] + 64), radius=20, fill=(78, 23, 38, 240), outline=with_alpha(RED, 180), width=2)
        draw.text((marker_x - 32, graph_box[1] + 30), "00:03", font=FONTS["micro"], fill=RED)
    composite_scene(frame, scene, alpha)


def draw_scene_two(frame: Image.Image, t: float) -> None:
    alpha = scene_alpha(t, 2.9, 6.35)
    if alpha <= 0:
        return
    scene = Image.new("RGBA", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(scene, "RGBA")
    p = ease_out((t - 3.05) / 0.72)
    x = int(118 + 56 * (1.0 - p))
    # Keep the copy inside the left composition column. The dashboard enters at
    # x=1070, so fixed headline/body fonts can otherwise render underneath it.
    draw.text(
        (x, 160),
        "RETTI READS THE DROP.",
        font=fit_text(draw, "RETTI READS THE DROP.", 870, 76, True),
        fill=INK,
    )
    subtitle = "Not a vague score. A timestamp, a reason, and the next edit."
    draw.text((x + 4, 278), subtitle, font=fit_text(draw, subtitle, 860, 34, False), fill=MUTED)

    bullet_y = 425
    for index, (label, detail, color) in enumerate(
        (
            ("REAL CURVE DATA", "The signal", CYAN),
            ("TIMESTAMPED DIAGNOSIS", "The cause", AMBER),
            ("STRUCTURAL FIX", "The next cut", GREEN),
        )
    ):
        delay = ease_out((t - (3.35 + index * 0.16)) / 0.62)
        by = bullet_y + index * 126
        draw.ellipse((x + 4, by + 8, x + 28, by + 32), fill=with_alpha(color, int(255 * delay)))
        draw.text((x + 55, by), label, font=FONTS["small_bold"], fill=with_alpha(INK, int(255 * delay)))
        draw.text((x + 55, by + 45), detail, font=FONTS["small"], fill=with_alpha(MUTED, int(255 * delay)))

    card_x = int(1070 + 120 * (1.0 - p))
    round_card(draw, (card_x, 180, 1780, 915), radius=42)
    pill(draw, card_x + 42, 225, "AUDIENCE RETENTION", BLUE)
    draw.text((card_x + 42, 312), "Video review", font=FONTS["subhead"], fill=INK)
    draw.text((card_x + 42, 375), "18:24 · 90% at open", font=FONTS["small"], fill=MUTED)

    chart = (card_x + 45, 470, 1740, 635)
    draw.rounded_rectangle(chart, radius=24, fill=(7, 14, 27, 235), outline=(38, 63, 100, 200), width=2)
    curve = []
    for index in range(80):
        u = index / 79
        cx = chart[0] + 22 + int(u * (chart[2] - chart[0] - 44))
        cy = chart[1] + 35 + int(70 * u + 18 * math.sin(u * 7) + (42 if u > 0.45 else 0))
        curve.append((cx, cy))
    draw.line(curve, fill=BLUE, width=5, joint="curve")
    marker = curve[36]
    draw.line((marker[0], chart[1] + 10, marker[0], chart[3] - 12), fill=with_alpha(AMBER, 220), width=3)
    draw.ellipse((marker[0] - 8, marker[1] - 8, marker[0] + 8, marker[1] + 8), fill=AMBER)

    draw.rounded_rectangle((card_x + 45, 682, 1740, 850), radius=25, fill=(26, 31, 44, 245), outline=with_alpha(AMBER, 110), width=2)
    draw.text((card_x + 72, 710), "04:58  DROP RISK", font=FONTS["small_bold"], fill=AMBER)
    draw.text((card_x + 72, 758), "Backstory runs flat. Intercut proof or cut the block.", font=fit_text(draw, "Backstory runs flat. Intercut proof or cut the block.", 585, 29, False), fill=INK)
    composite_scene(frame, scene, alpha)


def draw_scene_three(frame: Image.Image, t: float) -> None:
    alpha = scene_alpha(t, 6.05, 9.65)
    if alpha <= 0:
        return
    scene = Image.new("RGBA", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(scene, "RGBA")
    draw.text((120, 150), "DIAGNOSE. REWRITE. REVIEW.", font=fit_text(draw, "DIAGNOSE. REWRITE. REVIEW.", 1680, 92), fill=INK)
    draw.text((124, 270), "Three moments. Three concrete editing decisions.", font=FONTS["body"], fill=MUTED)

    cards = (
        ("00:47–00:59", "CUT DEAD AIR", "Tighten the setup before the first proof.", RED),
        ("04:58", "INTERCUT BACKSTORY", "Move evidence into the flat section.", AMBER),
        ("14:37", "HOLD THE PAYOFF", "Let the reveal breathe. End clean.", GREEN),
    )
    for index, (timecode, title, body, color) in enumerate(cards):
        p = ease_out((t - (6.45 + index * 0.2)) / 0.72)
        width = 515
        x = 118 + index * 560
        y = int(400 + 85 * (1.0 - p))
        round_card(draw, (x, y, x + width, y + 440), radius=34, fill=CARD_ALT)
        draw.rounded_rectangle((x + 30, y + 30, x + 190, y + 78), radius=22, fill=with_alpha(color, 35), outline=with_alpha(color, 170), width=2)
        draw.text((x + 54, y + 42), timecode, font=FONTS["micro"], fill=color)
        draw.text((x + 32, y + 136), title, font=fit_text(draw, title, 450, 42), fill=INK)
        draw.text((x + 32, y + 208), body, font=fit_text(draw, body, 450, 29, False), fill=MUTED)
        track_y = y + 334
        draw.rounded_rectangle((x + 32, track_y, x + width - 32, track_y + 28), radius=14, fill=(8, 14, 26, 255))
        segment_start = x + 72 + index * 44
        draw.rounded_rectangle((segment_start, track_y, min(x + width - 32, segment_start + 150), track_y + 28), radius=14, fill=color)
        draw.text((x + 32, y + 386), "EDIT NOTE", font=FONTS["micro"], fill=with_alpha(color, 220))
    composite_scene(frame, scene, alpha)


def draw_scene_four(frame: Image.Image, t: float) -> None:
    alpha = scene_alpha(t, 9.35, 12.85)
    if alpha <= 0:
        return
    scene = Image.new("RGBA", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(scene, "RGBA")
    draw.text((120, 148), "AUTOPSY → NEXT UPLOAD", font=FONTS["headline"], fill=INK)
    draw.text((124, 266), "One retention signal becomes the next plan, script, and cut.", font=FONTS["body"], fill=MUTED)

    left = (118, 390, 935, 888)
    right = (985, 390, 1802, 888)
    round_card(draw, left, radius=38)
    round_card(draw, right, radius=38)
    pill(draw, left[0] + 36, left[1] + 34, "EDIT REVIEW", CYAN)
    pill(draw, right[0] + 36, right[1] + 34, "SCRIPT LAB", BLUE)

    draw.text((left[0] + 38, left[1] + 118), "Cut 00:47–00:59", font=FONTS["subhead"], fill=INK)
    draw.text((left[0] + 38, left[1] + 185), "Frame-accurate feedback before upload.", font=FONTS["small"], fill=MUTED)
    for index in range(6):
        x1 = left[0] + 38 + index * 117
        color = RED if index == 2 else (47, 77, 119)
        draw.rounded_rectangle((x1, left[1] + 282, x1 + 88, left[1] + 362), radius=14, fill=with_alpha(color, 230))
    draw.line((left[0] + 270, left[1] + 250, left[0] + 270, left[1] + 404), fill=RED, width=4)

    draw.text((right[0] + 38, right[1] + 118), "Hook risk · line 12", font=FONTS["subhead"], fill=INK)
    draw.text((right[0] + 38, right[1] + 185), "Rewrite against patterns from the niche.", font=FONTS["small"], fill=MUTED)
    line_y = right[1] + 270
    line_widths = (600, 520, 645, 430)
    for index, line_width in enumerate(line_widths):
        color = AMBER if index == 1 else (62, 90, 130)
        draw.rounded_rectangle((right[0] + 38, line_y + index * 48, right[0] + 38 + line_width, line_y + 18 + index * 48), radius=9, fill=with_alpha(color, 225))

    labels = (("VIDEO REVIEW", CYAN), ("RETENTION DASHBOARD", GREEN), ("VIDEO PLANNER", AMBER))
    x = 120
    for label, color in labels:
        x += pill(draw, x, 942, label, color) + 18
    composite_scene(frame, scene, alpha)


def draw_scene_five(frame: Image.Image, t: float) -> None:
    alpha = scene_alpha(t, 12.55, 17.0, fade=0.55)
    if alpha <= 0:
        return
    scene = Image.new("RGBA", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(scene, "RGBA")
    p = ease_out((t - 12.75) / 0.9)

    glow = Image.new("RGBA", (WIDTH, HEIGHT))
    glow_draw = ImageDraw.Draw(glow, "RGBA")
    radius = int(210 + 35 * math.sin(t * 2.1))
    glow_draw.ellipse((960 - radius, 350 - radius, 960 + radius, 350 + radius), fill=(50, 132, 255, 90))
    glow = glow.filter(ImageFilter.GaussianBlur(85))
    scene.alpha_composite(glow)

    avatar_size = int(230 + 20 * p)
    avatar = AVATAR.resize((avatar_size, avatar_size), Image.Resampling.LANCZOS)
    scene.alpha_composite(avatar, (960 - avatar_size // 2, 350 - avatar_size // 2))
    title = "KNOW THE DROP. FIX THE NEXT CUT."
    title_font = fit_text(draw, title, 1640, 88)
    title_box = draw.textbbox((0, 0), title, font=title_font)
    draw.text(((WIDTH - (title_box[2] - title_box[0])) // 2, 565), title, font=title_font, fill=INK)
    subtitle = "A 17-SECOND RETTI PRODUCT-MOTION CONCEPT"
    subtitle_box = draw.textbbox((0, 0), subtitle, font=FONTS["small_bold"])
    draw.text(((WIDTH - (subtitle_box[2] - subtitle_box[0])) // 2, 695), subtitle, font=FONTS["small_bold"], fill=CYAN)

    draw.rounded_rectangle((596, 795, 1324, 867), radius=36, fill=(12, 22, 39, 235), outline=(59, 93, 141, 190), width=2)
    footer = "UNOFFICIAL SPEC · MYKEL NELSON · BUILT FROM PUBLIC PRODUCT MESSAGING"
    footer_font = fit_text(draw, footer, 660, 22)
    footer_box = draw.textbbox((0, 0), footer, font=footer_font)
    draw.text(((WIDTH - (footer_box[2] - footer_box[0])) // 2, 820), footer, font=footer_font, fill=MUTED)
    composite_scene(frame, scene, alpha)


def render_frame(frame_number: int) -> Image.Image:
    t = frame_number / FPS
    frame = BASE.copy()

    overlay = Image.new("RGBA", (WIDTH, HEIGHT))
    overlay_draw = ImageDraw.Draw(overlay, "RGBA")
    scan_y = int((t * 86) % (HEIGHT + 240)) - 120
    overlay_draw.rectangle((0, scan_y, WIDTH, scan_y + 160), fill=(76, 143, 255, 10))
    frame.alpha_composite(overlay)

    draw_scene_one(frame, t)
    draw_scene_two(frame, t)
    draw_scene_three(frame, t)
    draw_scene_four(frame, t)
    draw_scene_five(frame, t)
    draw_brand_bug(frame, t)

    if t < 0.2:
        curtain = Image.new("RGBA", (WIDTH, HEIGHT), (2, 5, 12, int(255 * (1.0 - t / 0.2))))
        frame.alpha_composite(curtain)
    if t > DURATION - 0.35:
        curtain = Image.new("RGBA", (WIDTH, HEIGHT), (2, 5, 12, int(255 * ((t - (DURATION - 0.35)) / 0.35))))
        frame.alpha_composite(curtain)
    return frame.convert("RGB")


def build_audio() -> None:
    samples = int(DURATION * SAMPLE_RATE)
    timeline = np.arange(samples, dtype=np.float64) / SAMPLE_RATE
    audio = 0.012 * np.sin(2 * np.pi * 46 * timeline)
    rng = np.random.default_rng(20260717)

    for transition in (0.32, 3.02, 6.18, 9.48, 12.68):
        start = int(transition * SAMPLE_RATE)
        impact_length = int(0.72 * SAMPLE_RATE)
        local = np.arange(impact_length, dtype=np.float64) / SAMPLE_RATE
        impact = (0.20 * np.sin(2 * np.pi * 58 * local) + 0.08 * np.sin(2 * np.pi * 116 * local)) * np.exp(-local * 7.5)
        stop = min(samples, start + impact_length)
        audio[start:stop] += impact[: stop - start]

        whoosh_start = max(0, start - int(0.34 * SAMPLE_RATE))
        whoosh_length = start - whoosh_start
        if whoosh_length:
            noise = rng.normal(0, 1, whoosh_length)
            smooth = np.convolve(noise, np.ones(35) / 35, mode="same")
            envelope = np.linspace(0, 1, whoosh_length) ** 2
            audio[whoosh_start:start] += 0.055 * smooth * envelope

    for tick in (1.55, 4.45, 4.75, 5.05, 7.15, 7.48, 7.81, 10.5, 11.0, 11.5):
        start = int(tick * SAMPLE_RATE)
        length = int(0.08 * SAMPLE_RATE)
        local = np.arange(length, dtype=np.float64) / SAMPLE_RATE
        click = 0.045 * np.sin(2 * np.pi * 820 * local) * np.exp(-local * 45)
        stop = min(samples, start + length)
        audio[start:stop] += click[: stop - start]

    fade = int(0.25 * SAMPLE_RATE)
    audio[:fade] *= np.linspace(0, 1, fade)
    audio[-fade:] *= np.linspace(1, 0, fade)
    peak = np.max(np.abs(audio))
    if peak > 0:
        audio = audio / peak * 0.78
    stereo = np.column_stack((audio, audio * 0.94))
    pcm = np.clip(stereo * 32767, -32768, 32767).astype("<i2")
    with wave.open(str(AUDIO), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())


def render_video() -> None:
    command = [
        "ffmpeg",
        "-y",
        "-loglevel",
        "error",
        "-f",
        "rawvideo",
        "-pix_fmt",
        "rgb24",
        "-s",
        f"{WIDTH}x{HEIGHT}",
        "-r",
        str(FPS),
        "-i",
        "-",
        "-an",
        "-c:v",
        "libx264",
        "-preset",
        "fast",
        "-crf",
        "18",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        str(SILENT_VIDEO),
    ]
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    assert process.stdin is not None

    contact_times = (1.8, 4.8, 7.8, 10.8, 13.9, 15.4)
    contact_frames = {int(value * FPS): value for value in contact_times}
    thumbs: list[Image.Image] = []
    cover_frame = int(14.7 * FPS)

    try:
        for frame_number in range(FRAMES):
            frame = render_frame(frame_number)
            process.stdin.write(frame.tobytes())
            if frame_number in contact_frames:
                thumbs.append(frame.resize((640, 360), Image.Resampling.LANCZOS))
            if frame_number == cover_frame:
                frame.save(COVER, optimize=True)
    finally:
        process.stdin.close()
    if process.wait() != 0:
        raise RuntimeError("FFmpeg video render failed")

    sheet = Image.new("RGB", (1920, 760), (5, 9, 18))
    sheet_draw = ImageDraw.Draw(sheet)
    for index, thumb in enumerate(thumbs):
        x = (index % 3) * 640
        y = (index // 3) * 360
        sheet.paste(thumb, (x, y))
    sheet_draw.rectangle((0, 720, 1920, 760), fill=(5, 9, 18))
    sheet_draw.text((28, 730), "UNOFFICIAL RETTI PRODUCT-MOTION SPEC · MYKEL NELSON · SIX-FRAME QA CONTACT SHEET", font=font(20, True), fill=(174, 193, 219))
    sheet.save(CONTACT_SHEET, quality=92, optimize=True)


def mux() -> None:
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-i",
            str(SILENT_VIDEO),
            "-i",
            str(AUDIO),
            "-c:v",
            "copy",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-shortest",
            "-movflags",
            "+faststart",
            str(OUTPUT),
        ],
        check=True,
    )


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing public reference asset: {SOURCE}")
    build_audio()
    render_video()
    mux()
    SILENT_VIDEO.unlink(missing_ok=True)
    AUDIO.unlink(missing_ok=True)
    print(f"Rendered {OUTPUT}")
    print(f"Rendered {CONTACT_SHEET}")
    print(f"Rendered {COVER}")


if __name__ == "__main__":
    main()
