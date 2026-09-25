import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.AudioContext? _ctx;

void primeTones() {
  try {
    final ctx = _ctx ??= web.AudioContext();
    if (ctx.state == 'suspended') ctx.resume();
  } catch (_) {}
}

Future<void> playTone({required double hz, required double seconds}) async {
  try {
    final ctx = _ctx ??= web.AudioContext();
    if (ctx.state == 'suspended') await ctx.resume().toDart;
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();
    osc.frequency.value = hz;
    gain.gain.setValueAtTime(0.0001, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.2, ctx.currentTime + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + seconds);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + seconds);
  } catch (_) {}
}
