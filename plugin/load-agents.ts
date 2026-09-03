import { readdirSync, readFileSync } from "node:fs"
import { join } from "node:path"
import { fileURLToPath } from "node:url"

interface YamlObject {
  [key: string]: YamlValue
}

type YamlValue =
  | string
  | number
  | boolean
  | null
  | YamlObject

function parseScalar(raw: string): YamlValue {
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

  if (/^-?\d+(?:\.\d+)?$/.test(value)) {
    return Number(value)
  }

  return value
}

function parseKey(raw: string): string {
  const key = raw.trim()

  if (
    (key.startsWith('"') && key.endsWith('"')) ||
    (key.startsWith("'") && key.endsWith("'"))
  ) {
    return key.slice(1, -1)
  }

  return key
}

/**
 * Parses the small YAML subset used by My-Agents frontmatter.
 *
 * Supports:
 * - scalar values
 * - nested mappings
 *
 * This is sufficient for fields such as:
 *
 * permission:
 *   edit: allow
 *   task:
 *     "*": deny
 */
function parseYamlObject(text: string): Record<string, YamlValue> {
  const root: Record<string, YamlValue> = {}

  const stack: Array<{
    indent: number
    value: Record<string, YamlValue>
  }> = [
    {
      indent: -1,
      value: root,
    },
  ]

  for (const line of text.split(/\r?\n/)) {
    if (!line.trim()) continue
    if (line.trimStart().startsWith("#")) continue

    const indent = line.match(/^ */)?.[0].length ?? 0
    const content = line.trim()

    const separator = content.indexOf(":")

    if (separator <= 0) continue

    const key = parseKey(content.slice(0, separator))
    const rawValue = content.slice(separator + 1).trim()

    while (
      stack.length > 1 &&
      indent <= stack[stack.length - 1].indent
    ) {
      stack.pop()
    }

    const parent = stack[stack.length - 1].value

    if (!rawValue) {
      const child: Record<string, YamlValue> = {}

      parent[key] = child

      stack.push({
        indent,
        value: child,
      })

      continue
    }

    parent[key] = parseScalar(rawValue)
  }

  return root
}

function readAgent(file: string) {
  const raw = readFileSync(file, "utf8")

  const match = raw.match(
    /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/,
  )

  if (!match) {
    return undefined
  }

  const metadata = parseYamlObject(match[1])

  const name =
    typeof metadata.name === "string" &&
    metadata.name.length > 0
      ? metadata.name
      : file
          .replace(/\.md$/, "")
          .split(/[\\/]/)
          .pop()

  if (!name) {
    return undefined
  }

  delete metadata.name

  return {
    name,
    ...metadata,
    prompt: raw.slice(match[0].length).trim(),
  }
}

/**
 * OpenCode 1.18.x plugin.
 *
 * The config hook receives the live merged configuration.
 * My-Agents injects the agents from this package into config.agent.
 *
 * This is intentionally different from ctx.agent.transform():
 * the transform API is not the mechanism OpenCode 1.18.x uses
 * to introduce arbitrary new agent definitions.
 */
export const server = async () => ({
  config: async (config: any) => {
    const agentsDir = join(
      fileURLToPath(new URL(".", import.meta.url)),
      "..",
      "agents",
    )

    const agents: Record<string, Record<string, unknown>> = {}

    for (const file of readdirSync(agentsDir).sort()) {
      if (!file.endsWith(".md")) {
        continue
      }

      const agent = readAgent(join(agentsDir, file))

      if (!agent) {
        continue
      }

      const { name, ...definition } = agent

      agents[name] = definition
    }

    /*
     * My-Agents provides the defaults.
     *
     * Existing user/project configuration wins over the
     * repository defaults.
     */
    config.agent = {
      ...agents,
      ...(config.agent ?? {}),
    }

    /*
     * Master is the default only when the user has not
     * explicitly selected another default agent.
     */
    if (!config.default_agent) {
      config.default_agent = "master"
    }

    console.log(
      `[my-agents] loaded ${Object.keys(agents).length} agents from ${agentsDir}`,
    )
  },
})

export default server