// Dual-runtime package entry point.
//
// OpenCode consumes the default export.
// DSH consumes the named `apply` export.
// Keeping both at the package root lets DSH load the bundle by package name
// while OpenCode continues to load the same Git package normally.

export { default } from './plugin/load-agents.ts'
export { apply } from './dsh/sync-preset.js'