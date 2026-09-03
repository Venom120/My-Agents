import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { homedir } from "node:os"

function syncFile(source, target) {
  const content = readFileSync(source, "utf8")
  if (!existsSync(target) || readFileSync(target, "utf8") !== content) {
    writeFileSync(target, content, "utf8")
  }
}

export function apply(ctx) {
  const packageRoot = join(dirname(fileURLToPath(import.meta.url)), "..")
  const sourceRoot = join(packageRoot, "agent-presets", "my-agents")
  const dshHome = process.env.DSH_HOME || join(homedir(), ".dsh")
  const targetRoot = join(dshHome, ".agent-presets", "my-agents")

  mkdirSync(targetRoot, { recursive: true })
  syncFile(join(sourceRoot, "agent.cordis.yml"), join(targetRoot, "agent.cordis.yml"))
  syncFile(join(sourceRoot, "preset.yml"), join(targetRoot, "preset.yml"))

  ctx.logger?.info?.("[my-agents] synchronized DSH preset to " + targetRoot)
}
