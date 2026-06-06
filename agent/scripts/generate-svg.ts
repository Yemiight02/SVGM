import type { GenerateSVGOptions } from "./lib/types";

/**
 * Deterministic, dependency-free SVG generator.
 *
 * The same `seed` always produces the same artwork. Output is always
 * well-formed XML — quotes inside attribute values are escaped, and the
 * `<svg>` root has the required `xmlns` declaration.
 */
export function generateSVG(opts: GenerateSVGOptions = {}): string {
  const size = opts.size ?? 512;
  const background = opts.background ?? "#0D0D0D";
  const palette = (opts.palette && opts.palette.length > 0)
    ? opts.palette
    : ["#2F80ED", "#FFFFFF", "#F5F5F5", "#FFD166", "#06D6A0"];
  const shapes = (opts.shapes && opts.shapes.length > 0)
    ? opts.shapes
    : ["circle", "rect", "polygon"];
  const seed = opts.seed ?? Math.floor(Math.random() * 1_000_000);

  const rng = mulberry32(seed);
  const elements: string[] = [];

  const count = 8 + Math.floor(rng() * 8); // 8..15 elements
  for (let i = 0; i < count; i++) {
    const shape = shapes[Math.floor(rng() * shapes.length)];
    const color = palette[Math.floor(rng() * palette.length)];
    elements.push(renderShape(shape, size, rng, color));
  }

  const body = elements.join("\n  ");
  return [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}" width="${size}" height="${size}">`,
    `  <rect x="0" y="0" width="${size}" height="${size}" fill="${escapeAttr(background)}"/>`,
    `  ${body}`,
    `</svg>`,
  ].join("\n");
}

function renderShape(
  shape: string,
  size: number,
  rng: () => number,
  color: string,
): string {
  const x = Math.floor(rng() * size);
  const y = Math.floor(rng() * size);
  const r = 8 + Math.floor(rng() * (size / 6));
  const w = 16 + Math.floor(rng() * (size / 4));
  const h = 16 + Math.floor(rng() * (size / 4));
  const op = (0.4 + rng() * 0.6).toFixed(2);
  const fill = escapeAttr(color);
  switch (shape) {
    case "circle":
      return `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" opacity="${op}"/>`;
    case "rect":
      return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}" opacity="${op}"/>`;
    case "polygon": {
      const sides = 3 + Math.floor(rng() * 4); // 3..6
      const pts: string[] = [];
      for (let i = 0; i < sides; i++) {
        const a = (Math.PI * 2 * i) / sides;
        const px = Math.round(x + r * Math.cos(a));
        const py = Math.round(y + r * Math.sin(a));
        pts.push(`${px},${py}`);
      }
      return `<polygon points="${pts.join(" ")}" fill="${fill}" opacity="${op}"/>`;
    }
    case "line":
      return `<line x1="${x}" y1="${y}" x2="${x + w}" y2="${y + h}" stroke="${fill}" stroke-width="2" opacity="${op}"/>`;
    case "path": {
      const cx = x + w / 2;
      const cy = y + h / 2;
      const d = `M ${x} ${cy} Q ${cx} ${y} ${x + w} ${cy}`;
      return `<path d="${d}" stroke="${fill}" stroke-width="2" fill="none" opacity="${op}"/>`;
    }
    default:
      return `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" opacity="${op}"/>`;
  }
}

function escapeAttr(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
}

/** Tiny seeded PRNG. https://stackoverflow.com/a/47593316 */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return function () {
    a |= 0;
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// CLI entry
if (require.main === module) {
  const args = parseArgs(process.argv.slice(2));
  const opts: GenerateSVGOptions = {
    shapes: args.shapes ? args.shapes.split(",") as any : undefined,
    palette: args.palette ? args.palette.split(",") : undefined,
    seed: args.seed ? Number(args.seed) : undefined,
    size: args.size ? Number(args.size) : undefined,
  };
  const svg = generateSVG(opts);
  if (args.out) {
    require("fs").writeFileSync(args.out, svg, "utf-8");
    console.error(`wrote ${svg.length} bytes to ${args.out}`);
  } else {
    process.stdout.write(svg);
  }
}

function parseArgs(argv: string[]): Record<string, string | undefined> {
  const out: Record<string, string | undefined> = {};
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k.startsWith("--")) {
      const key = k.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith("--")) {
        out[key] = next;
        i++;
      } else {
        out[key] = "true";
      }
    }
  }
  return out;
}
