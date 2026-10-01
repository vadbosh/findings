import type { Plugin } from "@opencode-ai/plugin"

// findings OpenCode plugin — the two halves of rules/found-defects-last.md that
// Claude Code and Codex get from hooks:
//
//   session.idle                   the reply is finished: record its "Found
//                                  along the way" section in the ledger
//                                  (bin/findings record), as found-defects-guard
//                                  does on Stop
//   experimental.chat.system.transform
//                                  before a request: open/urgent counts of the
//                                  project's ledger, as findings-hook does on
//                                  UserPromptSubmit
//
// What Opencode cannot get: blocking the end of a turn. A deferring phrase in
// the body is therefore not caught here — the rule text is the only guard.
//
// Thin delegating plugin: parsing, routing and dedupe live in bin/findings, the
// one implementation all three IDEs share. Fails quiet: a ledger error never
// reaches the session.

const BIN = process.env.HOME + "/.local/bin"
const SECTION = /^#{1,6}\s*(найдено попутно|найдено по ходу|попутно найдено|found along the way)\s*:?\s*$/im

// system.transform runs before every model request, tool steps included. The
// ledger changes a few times per session; asking it once per 30 s is plenty.
const TTL_MS = 30_000

export const FindingsPlugin: Plugin = async ({ client, $, directory }) => {
  const recorded = new Set<string>()
  // Keyed by session: the hook's second line names the session, and one
  // Opencode process can serve several.
  const cache = new Map<string, { at: number; text: string }>()

  return {
    event: async ({ event }: any) => {
      if (event?.type !== "session.idle") return
      const sessionID = event?.properties?.sessionID
      if (!sessionID) return
      try {
        const res: any = await client.session.messages({ path: { id: sessionID } })
        const messages: any[] = res?.data ?? res ?? []
        const last = [...messages].reverse().find((m) => m?.info?.role === "assistant")
        const id = last?.info?.id
        if (!id || recorded.has(id)) return
        recorded.add(id)
        const text = (last.parts ?? [])
          .filter((p: any) => p?.type === "text" && typeof p.text === "string")
          .map((p: any) => p.text)
          .join("\n")
        if (!SECTION.test(text)) return
        await $`printf '%s' ${text} | ${BIN}/findings record --cwd ${directory} --session ${sessionID}`
          .quiet()
          .nothrow()
        cache.clear() // the counts just changed
      } catch {
        // never disturb the session over the ledger
      }
    },

    "experimental.chat.system.transform": async (input: any, output: any) => {
      if (!output || !Array.isArray(output.system)) return
      const sessionID: string = input?.sessionID ?? ""
      const hit = cache.get(sessionID)
      if (!hit || Date.now() - hit.at > TTL_MS) {
        let text = ""
        try {
          const payload = JSON.stringify({ cwd: directory, session_id: sessionID })
          const res = await $`printf '%s' ${payload} | ${BIN}/findings-hook`.quiet().nothrow()
          if (res.exitCode === 0 && String(res.stdout).trim()) {
            text = JSON.parse(String(res.stdout))?.hookSpecificOutput?.additionalContext ?? ""
          }
        } catch {
          text = ""
        }
        cache.set(sessionID, { at: Date.now(), text })
      }
      const text = cache.get(sessionID)?.text
      if (text) output.system.push(text)
    },
  }
}
