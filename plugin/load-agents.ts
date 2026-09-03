import { readdirSync, readFileSync } from "node:fs"
import { join } from "node:path"
import { fileURLToPath } from "node:url"

function parseScalar(raw: string): unknown {
  const value = raw.trim()

  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1)
  }

  if (value === "true") return true
  if (value === "false") return false
  if (value === "null" || value === "~") return null
  if (/^-?\d+(\.\d+)?$/.test(value)) return Number(value)

  return value
}

function splitKey(line: string): [string, string] | null {
  const match = line.match(
    /^("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^:]+):(.*)$/,
  )

  if (!match) return null

  let key = match[1].trim()

  if (
    (key.startsWith('"') && key.endsWith('"')) ||
    (key.startsWith("'") && key.endsWith("'"))
  ) {
    key = key.slice(1, -1)
  }

  return [key, match[2].trim()]
}

function parseYaml(lines: string[]): Record<string, unknown> {
  const result: Record<string, unknown> = {}

  for (const line of lines) {
    const trimmed = line.trim()

    if (!trimmed || trimmed.startsWith("#")) continue

    const pair = splitKey(trimmed)
    if (!pair) continue

    const [key, value] = pair
    result[key] = parseScalar(value)
  }

  return result
}

export default async function MyAgentsPlugin(ctx: any) {
  const agentsDir = join(
    join(fileURLToPath(new URL(".", import.meta.url)), ".."),
    "agents",
  )

  await ctx.agent.transform((draft: any) => {
    for (const file of readdirSync(agentsDir).sort()) {
      if (!file.endsWith(".md")) continue

      const raw = readFileSync(join(agentsDir, file), "utf8")
      const frontmatter = raw.match(
        /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/,
      )

      if (!frontmatter) continue

      const metadata = parseYaml(frontmatter[1].split(/\r?\n/))
      const name =
        typeof metadata.name === "string" && metadata.name.length > 0
          ? metadata.name
          : file.replace(/\.md$/, "")

      delete metadata.name

      draft.update(name, (agent: any) => {
        Object.assign(agent, metadata)
        agent.system = raw.slice(frontmatter[0].length).trim()
      })

      if (!draft.get(name)) {
        // update() is intentionally used above for existing agents. For custom
        // agents, register the complete definition through the draft API.
        draft.add(name, {
          ...metadata,
          system: raw.slice(frontmatter[0].length).trim(),
        })
      }
    }

    if (draft.get("master")) {
      draft.default("master")
    }
  })

  console.log("[my-agents] agents loaded")
}
