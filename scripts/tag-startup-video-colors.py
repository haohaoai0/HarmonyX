"""Losslessly tag the supplied BT.601 startup clips for consistent native playback."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def frame_hashes(decoder, clip):
    result = subprocess.run([decoder, '-v', 'error', '-i', str(clip), '-map', '0:v:0',
                             '-pix_fmt', 'yuv420p', '-f', 'framemd5', '-'],
                            capture_output=True, check=True)
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ffmpeg', help='Defaults to the imageio_ffmpeg bundled binary')
    parser.add_argument('--backup', type=Path, required=True, help='Preserve every original clip here')
    args = parser.parse_args()
    if args.ffmpeg:
        decoder = args.ffmpeg
    else:
        import imageio_ffmpeg
        decoder = imageio_ffmpeg.get_ffmpeg_exe()
    root = Path(__file__).resolve().parents[1]
    clips = sorted((root / 'entry/src/main/resources/rawfile/startup').glob('*.mp4'))
    assert len(clips) == 25, 'Review the source color matrix when changing the supplied clip set'
    args.backup.mkdir(parents=True, exist_ok=True)
    report = []
    for clip in clips:
        saved = args.backup / clip.name
        if saved.exists():
            raise FileExistsError(f'Use a fresh backup directory: {saved}')
        shutil.copy2(clip, saved)
        before = frame_hashes(decoder, clip)
        with tempfile.TemporaryDirectory(prefix='startup-colors-') as staging:
            tagged = Path(staging) / clip.name
            # Update both container and bitstream metadata. Stream copy preserves
            # the original frames, cadence, duration, and compressed picture data.
            subprocess.run([decoder, '-v', 'error', '-i', str(clip), '-map', '0', '-c', 'copy',
                            '-bsf:v', 'h264_metadata=video_full_range_flag=0:matrix_coefficients=6',
                            '-color_range', 'tv', '-colorspace', 'smpte170m',
                            '-movflags', '+faststart+write_colr', str(tagged)], check=True)
            assert before == frame_hashes(decoder, tagged), f'{clip.name}: decoded YUV frames changed'
            shutil.copy2(tagged, clip)
        report.append({'name': clip.name, 'original_sha256': hashlib.sha256(saved.read_bytes()).hexdigest(),
                       'tagged_sha256': hashlib.sha256(clip.read_bytes()).hexdigest(),
                       'all_decoded_yuv_frames_identical': True})
        print(f'{clip.name}: tagged BT.601 limited range, every decoded frame unchanged', flush=True)
    (args.backup / 'tagging-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')


if __name__ == '__main__':
    main()
