#!/usr/bin/env node
/**
 * Offline-render Cuelume's 14 interaction cues to WAV (MIT, cuelume@0.1.2).
 *
 * Usage (from repo root):
 *   node tools/render_cuelume_wavs.mjs
 *
 * Requires network once to fetch cuelume + node-web-audio-api + wav-encoder
 * into a temp directory (not committed).
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT_DIR = path.join(REPO_ROOT, "assets/audio/sfx/ui/cuelume");
const SAMPLE_RATE = 44100;
const SOURCE_STOP_PADDING = 0.05;
const CLEANUP_MARGIN = 0.05;
const INAUDIBLE_GAIN = 0.001;

const work = fs.mkdtempSync(path.join(os.tmpdir(), "cuelume-render-"));
console.log(`Work dir: ${work}`);
fs.writeFileSync(
	path.join(work, "package.json"),
	JSON.stringify({ type: "module", private: true }, null, 2)
);
const install = spawnSync(
	"npm",
	["install", "cuelume@0.1.2", "node-web-audio-api", "wav-encoder"],
	{ cwd: work, encoding: "utf8" }
);
if (install.status !== 0) {
	console.error(install.stderr || install.stdout);
	process.exit(1);
}

const { OfflineAudioContext } = await import(
	pathToFileURL(path.join(work, "node_modules/node-web-audio-api/index.js")).href
);
const wavEncoder = (await import(pathToFileURL(path.join(work, "node_modules/wav-encoder/index.js")).href))
	.default;
const { RECIPES, sounds } = await import(
	pathToFileURL(path.join(work, "node_modules/cuelume/dist/sounds/recipes.js")).href
);

function sourceEnd(recipe) {
	return Math.max(
		...recipe.layers.map(
			(layer) => (layer.offset ?? 0) + layer.attack + layer.decay + SOURCE_STOP_PADDING
		)
	);
}

function shimmerTail(shimmer) {
	if (!shimmer || shimmer.feedback <= 0) return 0;
	if (shimmer.feedback >= 1) return shimmer.delay;
	return shimmer.delay * (1 + Math.ceil(Math.log(INAUDIBLE_GAIN) / Math.log(shimmer.feedback)));
}

function recipeDuration(recipe) {
	return sourceEnd(recipe) + shimmerTail(recipe.shimmer) + CLEANUP_MARGIN;
}

function renderTone(context, destination, layer, startTime) {
	const oscillator = context.createOscillator();
	oscillator.type = layer.waveform;
	oscillator.frequency.setValueAtTime(layer.frequency, startTime);
	if (layer.detune) oscillator.detune.value = layer.detune;
	if (layer.glideTo !== undefined) {
		const glideTime = layer.glideTime ?? layer.attack + layer.decay;
		oscillator.frequency.exponentialRampToValueAtTime(layer.glideTo, startTime + glideTime);
	}
	const gain = context.createGain();
	gain.gain.setValueAtTime(0.0001, startTime);
	gain.gain.exponentialRampToValueAtTime(layer.peak, startTime + layer.attack);
	gain.gain.exponentialRampToValueAtTime(0.0001, startTime + layer.attack + layer.decay);
	oscillator.connect(gain).connect(destination);
	oscillator.start(startTime);
	oscillator.stop(startTime + layer.attack + layer.decay + SOURCE_STOP_PADDING);
}

function renderNoise(context, destination, layer, startTime) {
	const duration = layer.attack + layer.decay + SOURCE_STOP_PADDING;
	const length = Math.max(1, Math.floor(duration * context.sampleRate));
	const buffer = context.createBuffer(1, length, context.sampleRate);
	const data = buffer.getChannelData(0);
	for (let i = 0; i < length; i++) data[i] = 2 * Math.random() - 1;
	const source = context.createBufferSource();
	source.buffer = buffer;
	const filter = context.createBiquadFilter();
	filter.type = layer.filterType;
	filter.frequency.value = layer.filterFrequency;
	if (layer.filterQ !== undefined) filter.Q.value = layer.filterQ;
	const gain = context.createGain();
	gain.gain.setValueAtTime(0.0001, startTime);
	gain.gain.exponentialRampToValueAtTime(layer.peak, startTime + layer.attack);
	gain.gain.exponentialRampToValueAtTime(0.0001, startTime + layer.attack + layer.decay);
	source.connect(filter).connect(gain).connect(destination);
	source.start(startTime);
	source.stop(startTime + duration);
}

function attachShimmer(context, source, destination, shimmer) {
	const delay = context.createDelay(1);
	delay.delayTime.value = shimmer.delay;
	const feedbackFilter = context.createBiquadFilter();
	feedbackFilter.type = "lowpass";
	feedbackFilter.frequency.value = shimmer.lowpass;
	const feedbackGain = context.createGain();
	feedbackGain.gain.value = shimmer.feedback;
	const wetGain = context.createGain();
	wetGain.gain.value = shimmer.wet;
	source.connect(delay);
	delay.connect(feedbackFilter);
	feedbackFilter.connect(feedbackGain);
	feedbackGain.connect(delay);
	feedbackFilter.connect(wetGain);
	wetGain.connect(destination);
}

async function renderSound(name) {
	const recipe = RECIPES[name];
	const duration = recipeDuration(recipe);
	const length = Math.max(1, Math.ceil(duration * SAMPLE_RATE));
	const context = new OfflineAudioContext(1, length, SAMPLE_RATE);
	const master = context.createGain();
	master.gain.value = recipe.masterGain;
	master.connect(context.destination);
	if (recipe.shimmer) {
		attachShimmer(context, master, context.destination, recipe.shimmer);
	}
	for (const layer of recipe.layers) {
		const startTime = layer.offset ?? 0;
		if (layer.kind === "tone") renderTone(context, master, layer, startTime);
		else renderNoise(context, master, layer, startTime);
	}
	const rendered = await context.startRendering();
	const channel = rendered.getChannelData(0);
	let end = channel.length - 1;
	const threshold = 1e-4;
	while (end > 0 && Math.abs(channel[end]) < threshold) end--;
	end = Math.min(channel.length, end + Math.floor(0.02 * SAMPLE_RATE));
	const trimmed = channel.subarray(0, end);
	const encoded = await wavEncoder.encode({
		sampleRate: SAMPLE_RATE,
		channelData: [trimmed],
	});
	return Buffer.from(encoded);
}

fs.mkdirSync(OUT_DIR, { recursive: true });
for (const name of sounds) {
	const buf = await renderSound(name);
	const outPath = path.join(OUT_DIR, `cuelume-${name}.wav`);
	fs.writeFileSync(outPath, buf);
	console.log(`OK ${name} (${buf.length} bytes)`);
}
fs.copyFileSync(
	path.join(work, "node_modules/cuelume/LICENSE"),
	path.join(OUT_DIR, "LICENSE-cuelume.txt")
);
console.log(`Wrote ${sounds.length} WAVs + LICENSE to ${OUT_DIR}`);
