// The APK uses this neutral pattern until locally decoded samples are ready.
// Recorded samples are peak amplitudes from AVRecorder, never synthetic noise.
export class ChatVoice {
  static time(milliseconds: number): string {
    const seconds: number = Number.isFinite(milliseconds) ? Math.max(0, Math.ceil(milliseconds / 1000)) : 0;
    return Math.floor(seconds / 60).toString() + ':' + (seconds % 60).toString().padStart(2, '0');
  }

  static bars(samples: number[], count: number = 32): number[] {
    const fallback: number[] = [0.3, 0.55, 0.85, 0.45, 0.7, 1, 0.6, 0.35];
    const values: number[] = samples.length > 0 ? samples : fallback;
    let peak: number = 0;
    for (let i: number = 0; i < values.length; i++) {
      if (Number.isFinite(values[i])) { peak = Math.max(peak, Math.abs(values[i])); }
    }
    const bars: number[] = [];
    for (let i: number = 0; i < count; i++) {
      const start: number = Math.floor(i * values.length / count);
      const end: number = Math.max(start + 1, Math.floor((i + 1) * values.length / count));
      let amplitude: number = 0;
      for (let j: number = start; j < end && j < values.length; j++) {
        if (Number.isFinite(values[j])) { amplitude = Math.max(amplitude, Math.abs(values[j])); }
      }
      bars.push(peak > 0 ? Math.max(0.08, Math.min(1, amplitude / peak)) : 0.08);
    }
    return bars;
  }
}
