import fs from "node:fs";
import path from "node:path";

const FILE_NAME = "buildinfo.txt";
const MAX_LEVELS = 8;

function searchUpward(startDir: string): string | null {
  let dir = startDir;

  for (let level = 0; level < MAX_LEVELS; level += 1) {
    const candidate = path.join(dir, FILE_NAME);

    if (fs.existsSync(candidate)) {
      return candidate;
    }

    const parent = path.dirname(dir);

    if (parent === dir) {
      break;
    }

    dir = parent;
  }

  return null;
}

/**
 * Locate the repo-root `buildinfo.txt`. The server runs from a bundled
 * `dist/index.mjs`, so its depth below the repo root differs from the source
 * layout; searching upward from both the bundle and the working directory
 * keeps dev and published builds working without hardcoding a depth.
 */
function findBuildInfoFile(): string | null {
  return searchUpward(import.meta.dirname) ?? searchUpward(process.cwd());
}

const buildInfoPath = findBuildInfoFile();

/**
 * Current build number, or `undefined` when `buildinfo.txt` is missing or
 * empty. The path is resolved once, but the contents are read per call so
 * bumping the number takes effect without restarting the server.
 */
export function readBuildNumber(): string | undefined {
  if (!buildInfoPath) {
    return undefined;
  }

  try {
    const text = fs.readFileSync(buildInfoPath, "utf8").trim();

    return text === "" ? undefined : text;
  } catch {
    return undefined;
  }
}
