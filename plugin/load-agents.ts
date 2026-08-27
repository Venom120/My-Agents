import { readdirSync, readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

function parseScalar(raw) {
  const t = raw.trim()
  if (
    (t.startsWith('"') && t.endsWith('"')) ||
    (t.startsWith("'") && t.endsWith("'"))
  ) {
    return t.slice(1, -1)
  }
  if (t === "true") return true
  if (t === "false") return false
  if (t === "null" || t === "~" || t === "") return null
  if (/^-?\d+(\.\d+)?$/.test(t)) return Number(t)
  return t
}

function splitKey(text) {
  const m = text.match(/^("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^:]+):(.*)$/)
  if (!m) return null
  let key = m[1].trim()
  if (
    (key.startsWith('"') && key.endsWith('"')) ||
    (key.startsWith("'") && key.endsWith("'"))
  ) {
    key = key.slice(1, -1)
  }
  return [key, m[2].trim()]
}

function parseYaml(lines) {
  let i = 0
  function walk(indent) {
    const obj = {}
    while (i < lines.length) {
      const line = lines[i]
      const trimmed = line.trim()
      if (!trimmed || trimmed.startsWith("#")) {
        i += 1
        continue
      }
      const cur = line.length - line.trimStart().length
      if (cur < indent) break
      const kv = splitKey(trimmed)
      if (!kv) {
        i += 1
        continue
      }
      const [key, rest] = kv
      i += 1
      obj[key] = rest === "" ? walk(cur + 1) : parseScalar(rest)
    }
    return obj
  }
  return walk(0)
}

export default async function () {
  const agentsDir = join(
    dirname(fileURLToPath(import.meta.url)),
    "..",
    "agents",
  )
  return {
    config(config) {
      for (const file of readdirSync(agentsDir)) {
        if (!file.endsWith(".md")) continue
        const raw = readFileSync(join(agentsDir, file), "utf8")
        const fm = raw.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)
        if (!fm) continue
        const meta = parseYaml(fm[1].split(/\r?\n/))
        const name =
          typeof meta.name === "string" && meta.name
            ? meta.name
            : file.replace(/\.md$/, "")
        delete meta.name
        config.agent = {
          ...(config.agent || {}),
          [name]: { ...meta, prompt: raw.slice(fm[0].length).trim() },
        }
      }

      // Expose this repo's skills/ folder so skills load too (no local clone needed).
      const skillsDir = join(dirname(fileURLToPath(import.meta.url)), "..", "skills")
      config.skills = config.skills ?? {}
      const paths = Array.isArray(config.skills.paths) ? config.skills.paths : []
      if (!paths.includes(skillsDir)) paths.push(skillsDir)
      config.skills.paths = paths
    },
  }
}
