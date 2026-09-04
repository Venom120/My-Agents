
// Dual-runtime entry point: DSH consumes the named `apply` export,
// while OpenCode consumes the default export (the plugin loader).
export { apply } from './dsh/sync-preset.js'
export { default } from './plugin/load-agents.js'