import { spawn } from "node:child_process"
import type { Plugin } from "@opencode-ai/plugin"

// findings OpenCode plugin — the two halves of rules/found-defects-last.md that
// Claude Code and Codex get from hooks:
//
//   the reply is finished          record its "Found along the way" section in
//                                  the ledger (bin/findings record), as
//                                  found-defects-guard does on Stop
//   before a model request         open/urgent counts of the project's ledger
//                                  added to the system prompt, as findings-hook
//                                  does on UserPromptSubmit
//
// What Opencode cannot get: blocking the end of a turn. A deferring phrase in
// the body is therefore not caught here — the rule text is the only guard.
//
// Thin delegating plugin: parsing, routing and dedupe live in bin/findings, the
// one implementation all three IDEs share. Fails quiet: a ledger error never
// reaches the session.
//
// Dual-shape, like rtk.ts. 2.x (setup): session.text.ended carries each text
// block of a reply and session.execution.succeeded marks the end of the turn;
// the `context` hook adds the counts. 1.x (server): session.idle, the session
// messages through the client, and experimental.chat.system.transform. No Bun
// `$`: node:child_process runs under both.

const BIN = process.env.HOME + "/.local/bin"
const SECTION = /^#{1,6}\s*(найдено попутно|найдено по ходу|попутно найдено|found along the way)\s*:?\s*$/im

// The system prompt is rebuilt before every model request, tool steps
// included. The ledger changes a few times per session; asking it once per
// 30 s is plenty.
const TTL_MS = 30_000

function runCli(bin: string, args: string[], stdin: string, timeout = 15000): Promise<{ code: number; stdout: string }> {
  return new Promise((resolve) => {
    const p = spawn(bin, args, { stdio: ["pipe", "pipe", "ignore"] })
    let stdout = ""
    const t = setTimeout(() => p.kill(), timeout)
    p.stdout.on("data", (d) => (stdout += d))
    p.on("error", () => (clearTimeout(t), resolve({ code: 127, stdout })))
    p.on("close", (c) => (clearTimeout(t), resolve({ code: c ?? 1, stdout })))
    p.stdin.on("error", () => {})
    p.stdin.end(stdin)
  })
}

const record = (text: string, cwd: string, sessionID: string) =>
  runCli(`${BIN}/findings`, ["record", "--cwd", cwd, "--session", sessionID], text)

// Keyed by session: the hook's second line names the session, and one Opencode
// process can serve several.
function makeCounts(directory: () => string) {
  const cache = new Map<string, { at: number; text: string }>()
  return {
    clear: () => cache.clear(),
    async get(sessionID: string): Promise<string> {
      const hit = cache.get(sessionID)
      if (!hit || Date.now() - hit.at > TTL_MS) {
        let text = ""
        try {
          const res = await runCli(`${BIN}/findings-hook`, [], JSON.stringify({ cwd: directory(), session_id: sessionID }))
          if (res.code === 0 && res.stdout.trim()) {
            text = JSON.parse(res.stdout)?.hookSpecificOutput?.additionalContext ?? ""
          }
        } catch {
          text = ""
        }
        cache.set(sessionID, { at: Date.now(), text })
      }
      return cache.get(sessionID)?.text ?? ""
    },
  }
}

export const FindingsPlugin: Plugin = async ({ client, directory }: any) => {
  const recorded = new Set<string>()
  const counts = makeCounts(() => directory)

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
        await record(text, directory, sessionID)
        counts.clear() // the counts just changed
      } catch {
        // never disturb the session over the ledger
      }
    },

    "experimental.chat.system.transform": async (input: any, output: any) => {
      if (!output || !Array.isArray(output.system)) return
      const text = await counts.get(input?.sessionID ?? "")
      if (text) output.system.push(text)
    },
  }
}

export default {
  id: "findings",
  setup(ctx: any) {
    const counts = makeCounts(() => ctx.location?.directory ?? process.cwd())
    const seen = new Set<string>() // the stream delivers each event more than once
    // Text of the reply being written, per session: one entry per text block,
    // keyed by the assistant message so a new reply starts from empty.
    const reply = new Map<string, { message: string; blocks: string[] }>()
    const dirs = new Map<string, string>()
    const controller = new AbortController()

    void (async () => {
      for await (const ev of ctx.event.subscribe({ signal: controller.signal })) {
        try {
          if (!ev?.id || seen.has(ev.id)) continue
          const sessionID = String(ev?.data?.sessionID ?? "")
          if (!sessionID) continue

          if (ev.type === "session.text.ended") {
            seen.add(ev.id)
            const message = String(ev.data.assistantMessageID ?? "")
            let r = reply.get(sessionID)
            if (!r || r.message !== message) reply.set(sessionID, (r = { message, blocks: [] }))
            r.blocks.push(String(ev.data.text ?? ""))
            if (ev.location?.directory) dirs.set(sessionID, ev.location.directory)
          } else if (ev.type === "session.execution.succeeded") {
            seen.add(ev.id)
            const text = (reply.get(sessionID)?.blocks ?? []).join("\n")
            reply.delete(sessionID)
            if (!SECTION.test(text)) continue
            await record(text, dirs.get(sessionID) ?? ctx.location?.directory ?? process.cwd(), sessionID)
            counts.clear() // the counts just changed
          }
        } catch {
          // never disturb the session over the ledger
        }
      }
    })().catch(() => {})

    return ctx.session
      .hook("context", async (e: any) => {
        const text = await counts.get(String(e?.sessionID ?? ""))
        if (text) e.system.push({ type: "text", text })
      })
      .then(() => () => controller.abort())
  },
  server: FindingsPlugin,
}
