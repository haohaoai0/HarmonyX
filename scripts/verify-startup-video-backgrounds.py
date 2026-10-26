"""Check decoded video background colors without including the animated logo."""
import argparse
import json
from pathlib import Path
import re
import struct
import subprocess

import numpy as np
from PIL import Image


def dominant_rgb(pixels):
    colors = pixels.astype(np.uint32)
    packed = (colors[:, 0] << 16) | (colors[:, 1] << 8) | colors[:, 2]
    values, counts = np.unique(packed, return_counts=True)
    index = counts.argmax()
    value = int(values[index])
    return f'#{value:06X}', round(int(counts[index]) / len(packed), 4)


def color_metadata(decoder, clip):
    # Both the MP4 colr atom and H.264 VUI must identify the source's BT.601
    # limited-range samples. Untagged video can look correct in FFmpeg while
    # a hardware player defaults to BT.709 and produces a visible blue seam.
    data = clip.read_bytes()
    marker = data.find(b'colrnclx')
    assert marker >= 4, f'{clip.name}: missing MP4 nclx color description'
    assert struct.unpack_from('>I', data, marker - 4)[0] == 19, f'{clip.name}: invalid colr atom'
    primaries, transfer, matrix, range_flags = struct.unpack_from('>HHHB', data, marker + 8)
    assert matrix == 6 and range_flags >> 7 == 0, f'{clip.name}: MP4 must declare BT.601 limited range'
    result = subprocess.run([decoder, '-v', 'info', '-i', str(clip), '-map', '0:v:0',
                             '-c:v', 'copy', '-bsf:v', 'trace_headers', '-frames:v', '1',
                             '-f', 'null', '-'], capture_output=True, check=True)
    header = result.stderr.decode('utf8', errors='replace')
    for field, expected in [('video_signal_type_present_flag', 1),
                            ('colour_description_present_flag', 1),
                            ('video_full_range_flag', 0), ('matrix_coefficients', 6)]:
        values = re.findall(r'\b' + field + r'\s+[01]+\s+=\s+(\d+)', header)
        assert values and all(int(value) == expected for value in values), (
            f'{clip.name}: H.264 {field} must be {expected}, got {values}')
    return {'matrix': 'BT.601 (SMPTE 170M)', 'matrix_coefficients': matrix,
            'range': 'limited', 'mp4_nclx': True, 'h264_vui': True,
            'colour_primaries': primaries, 'transfer_characteristics': transfer}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ffmpeg', help='Path to ffmpeg; defaults to imageio_ffmpeg bundled binary')
    parser.add_argument('--report', type=Path, help='Write the color evidence as JSON')
    args = parser.parse_args()
    if args.ffmpeg:
        decoder = args.ffmpeg
    else:
        import imageio_ffmpeg
        decoder = imageio_ffmpeg.get_ffmpeg_exe()
    root = Path(__file__).resolve().parents[1]
    resources = root / 'entry/src/main/resources'
    palettes = []
    for theme in ['base', 'dark']:
        colors = json.loads((resources / theme / 'element/color.json').read_text(encoding='utf-8-sig'))['color']
        palettes.append({entry['name']: entry['value'].upper() for entry in colors})
    report = {'sampling': 'Original-resolution RGB decode, 4 fps, dominant color of the outer 10% rim; no resizing or logo averaging.', 'clips': []}
    for clip in sorted((resources / 'rawfile/startup').glob('*.mp4')):
        metadata = color_metadata(decoder, clip)
        still = Image.open(clip.with_suffix('.webp')).convert('RGB')
        width, height = still.size
        result = subprocess.run([decoder, '-v', 'error', '-i', str(clip), '-vf', 'fps=4',
                                 '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], capture_output=True, check=True)
        frames = np.frombuffer(result.stdout, np.uint8).reshape(-1, height, width, 3)
        rim = np.ones((height, width), dtype=bool)
        rim[height // 10:height - height // 10, width // 10:width - width // 10] = False
        color, fraction = dominant_rgb(frames[:, rim, :].reshape(-1, 3))
        still_color, _ = dominant_rgb(np.asarray(still)[rim])
        resource = 'startup_animation_twitter_blue' if clip.stem == 'launch_twitter_blue' else (
            'startup_animation_dark' if clip.stem.endswith('_dark') else 'startup_animation_light')
        for palette in palettes:
            assert color == palette[resource], f'{clip.name}: {color} != {resource}: {palette[resource]}'
        assert still_color == color, f'{clip.name}: last frame background {still_color} != video {color}'
        report['clips'].append({'name': clip.name, 'size': [width, height], 'background': color,
                                'resource': resource, 'dominant_fraction': fraction,
                                'last_frame_background': still_color, 'color_metadata': metadata})
        print(f'{clip.name}: {color}, video/still/light-dark resources and BT.601 limited-range tags match')
    assert len(report['clips']) == 25, 'Verify coverage when adding or removing startup videos'
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf8')


if __name__ == '__main__':
    main()
