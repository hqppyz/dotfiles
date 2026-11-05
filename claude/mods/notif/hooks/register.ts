import type { EngineInterface, Register } from 'claude-code'

// Per-project ntfy notifications.
//
// The mode (off | ask | all, default off) lives in the project's
// transcript folder, ~/.claude/projects/<encoded-project>/notif-mode, so the
// project dir stays clean; ~/.claude/statusline.sh reads the same file.
// notif-last, next to it, keeps the last on mode for the /notif toggle.
// notif-log, next to it, records every push attempt (time, path, mode, text).
//
//   /notif               toggle: off <-> the last on mode (ask or all, default ask)
//   /notif <mode>        set it for this project
//   /notif send <text>   push <text> now
//   mcp__notif__send     the same push, as a tool Claude calls
//   mcp__notif__mode     set the mode, as a tool Claude calls
//
// Automatic pings: "ask" and "all" on AskUserQuestion and permission dialogs,
// "all" also when a main turn ends. NTFY_URL and NTFY_TOKEN come from the
// environment (settings.json env), else from ~/.claude/.env (KEY=VALUE lines).

const MODES = ['off', 'ask', 'all'] as const
type Mode = (typeof MODES)[number]

const isMode = (s: string): s is Mode => (MODES as readonly string[]).includes(s)

// Set when Claude pushed by itself this turn, so the turn-end ping is skipped.
let sentThisTurn = false
// Open AskUserQuestion calls: their dialog also raises a permission_prompt
// notification, already pinged as the question itself.
let openQuestions = 0

// The transcript folder of this session: the one holding <session id>.jsonl.
async function projectDir($: EngineInterface): Promise<string> {
  const cfg = (await $.env.get('CLAUDE_CONFIG_DIR')) ?? `${await $.env.get('HOME')}/.claude`
  const id = await $.session.id()
  for (const entry of await $.fs.list(`${cfg}/projects`)) {
    const dir = `${cfg}/projects/${entry.name}`
    if (await $.fs.exists(`${dir}/${id}.jsonl`)) return dir
  }
  // No transcript yet: the folder it will get, named after the project root.
  return `${cfg}/projects/${(await $.session.root()).replace(/[^A-Za-z0-9]/g, '-')}`
}

async function readMode($: EngineInterface): Promise<Mode> {
  const file = `${await projectDir($)}/notif-mode`
  if (!(await $.fs.exists(file))) return 'off'
  const m = (await $.fs.read(file)).trim()
  return isMode(m) ? m : 'off'
}

// The mode a bare /notif turns back on: the last one set other than off.
async function readLast($: EngineInterface): Promise<Mode> {
  const file = `${await projectDir($)}/notif-last`
  if (!(await $.fs.exists(file))) return 'ask'
  const m = (await $.fs.read(file)).trim()
  return m === 'all' ? 'all' : 'ask'
}

async function writeMode($: EngineInterface, mode: Mode): Promise<string> {
  const dir = await projectDir($)
  await $.fs.write(`${dir}/notif-mode`, `${mode}\n`)
  if (mode !== 'off') await $.fs.write(`${dir}/notif-last`, `${mode}\n`)
  return `notif ${mode} (${dir.split('/').pop()})`
}

// Which code path asked for a push; logged to tell stray pushes apart.
type Via = 'command' | 'tool' | 'ping' | 'turn-end'

const LOG_LINES = 200

// log: append one line to notif-log, keeping the last LOG_LINES. Never throws.
async function log($: EngineInterface, line: string) {
  try {
    const file = `${await projectDir($)}/notif-log`
    const old = (await $.fs.exists(file)) ? (await $.fs.read(file)).split('\n').filter(Boolean) : []
    await $.fs.write(file, [...old, line].slice(-LOG_LINES).join('\n') + '\n')
  } catch {}
}

async function send($: EngineInterface, via: Via, text: string): Promise<string> {
  const out = await post($, text)
  const mode = await readMode($).catch(() => '?')
  await log($, `${new Date().toISOString()} via=${via} mode=${mode} session=${await $.session.id()} ${out}`)
  return out
}

// envVar: name from the environment, else from ~/.claude/.env, which keeps
// secrets out of settings.json.
async function envVar($: EngineInterface, name: string): Promise<string | undefined> {
  const value = await $.env.get(name)
  if (value) return value
  const cfg = (await $.env.get('CLAUDE_CONFIG_DIR')) ?? `${await $.env.get('HOME')}/.claude`
  const file = `${cfg}/.env`
  if (!(await $.fs.exists(file))) return undefined
  for (const line of (await $.fs.read(file)).split('\n')) {
    const m = line.match(/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/)
    if (m?.[1] === name) return m[2].replace(/^(['"])(.*)\1$/, '$2')
  }
  return undefined
}

async function post($: EngineInterface, text: string): Promise<string> {
  const url = await envVar($, 'NTFY_URL')
  const token = await envVar($, 'NTFY_TOKEN')
  if (!url || !token) return 'notif: NTFY_URL or NTFY_TOKEN is not set'
  const project = (await $.session.root()).split('/').pop() || '?'
  const body = `[${project}] ${text.replace(/\s+/g, ' ').trim().slice(0, 300)}`
  try {
    const res = await $.http.fetch(url, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, Title: 'Claude Code' },
      body,
    })
    return res.ok ? `notif sent: ${body}` : `notif: ntfy answered ${res.status}`
  } catch (err) {
    return `notif: ${String(err)}`
  }
}

// summarize: the turn's answer as a one-line "Done: ..." push, by Haiku (a few
// hundred tokens). Falls back to the answer's first sentence.
async function summarize($: EngineInterface, answer: string): Promise<string> {
  const plain = answer.replace(/[*_`#>]/g, '').replace(/\s+/g, ' ').trim()
  const fallback = `Done: ${plain.split(/(?<=[.!?])\s/)[0]?.slice(0, 120) ?? ''}`
  const r = await $.model
    .complete({
      model: 'claude-haiku-5-5',
      system: 'Summarize this coding assistant reply as a one-line push notification starting with "Done:".',
      prompt: plain.slice(0, 4000),
      maxTokens: 60,
    })
    .catch(() => undefined)
  const line = r?.isAnswered ? r.text.replace(/\s+/g, ' ').trim() : ''
  if (!line) return fallback
  return line.startsWith('Done:') ? line : `Done: ${line}`
}

// ping: push an "ask" event ("Question: ...") when the mode allows it.
async function ping($: EngineInterface, text: string) {
  const mode = await readMode($)
  if (mode === 'ask' || mode === 'all') await send($, 'ping', `Question: ${text}`)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'notif',
      description: 'ntfy notifications: toggle off and on, set the mode, or send a message',
      argumentHint: 'off|ask|all | send <text>',
      immediate: true,
    })
    await $.tool.register({
      name: 'send',
      description:
        "Send the user a push notification (ntfy) with a short message. Use when the user asks to be notified.",
      inputSchema: {
        type: 'object',
        properties: { text: { type: 'string', description: 'The message, one short line' } },
        required: ['text'],
      },
      isDeferred: true,
    })
    await $.tool.register({
      name: 'mode',
      description:
        "Set this project's push notification mode: off (none), ask (when Claude asks or needs permission), all (also when a turn ends). Use when the user asks to change when they are notified.",
      inputSchema: {
        type: 'object',
        properties: { mode: { type: 'string', enum: [...MODES] } },
        required: ['mode'],
      },
      isDeferred: true,
    })
    return next(e)
  })

  on('command.run', { command: 'notif' }, async ($, e) => {
    const args = e.args.trim()
    const [sub = '', ...rest] = args.split(/\s+/)
    const text = rest.join(' ')
    const isValid = (sub === '' || isMode(sub)) && text === ''
    if (sub === 'send' && text !== '') return { text: await send($, 'command', text) }
    if (!isValid) return { text: 'usage: /notif [off|ask|all | send <text>]' }

    if (sub !== '') return { text: await writeMode($, sub as Mode) }
    return { text: await writeMode($, (await readMode($)) === 'off' ? await readLast($) : 'off') }
  })

  // Typeahead for the first argument: the modes and send, with what each does.
  // The engine's own hint covers the empty argument.
  const ROWS = [
    { text: 'off', description: 'no pushes for this project' },
    { text: 'ask', description: 'push when Claude asks or needs permission' },
    { text: 'all', description: 'also push when Claude finishes a turn' },
    { text: 'send', description: '<text>: push a message now' },
  ]
  on('prompt.autocomplete', async ($, e, next) => {
    const m = /^\/notif\s+(\S*)$/.exec(e.text.slice(0, e.cursor))
    if (!m) return next(e)
    const sub = m[1] ?? ''
    const rows = ROWS.filter(r => r.text.startsWith(sub))
    return { suggestions: [...rows, ...(await next(e)).suggestions] }
  })

  on('tool.call', { tool: 'mcp__notif__send' }, async ($, e) => {
    const text = String((e as { text?: unknown }).text ?? '')
    if (text === '') return { result: 'notif: empty text', text: 'notif: empty text', isError: true as const }
    const out = await send($, 'tool', text)
    sentThisTurn = true
    return out.startsWith('notif sent')
      ? { result: out, text: out }
      : { result: out, text: out, isError: true as const }
  }).catch(() => ({ result: 'notif: send failed', text: 'notif: send failed', isError: true as const }))

  on('tool.call', { tool: 'mcp__notif__mode' }, async ($, e) => {
    const mode = String((e as { mode?: unknown }).mode ?? '')
    if (!isMode(mode)) {
      const out = `notif: mode must be one of ${MODES.join(', ')}`
      return { result: out, text: out, isError: true as const }
    }
    const out = await writeMode($, mode)
    return { result: out, text: out }
  }).catch(() => ({ result: 'notif: mode change failed', text: 'notif: mode change failed', isError: true as const }))

  on('tool.call', { tool: 'AskUserQuestion' }, async ($, e, next) => {
    const q = (e as { questions?: { question?: string }[] }).questions?.[0]?.question
    void ping($, q ?? 'Claude has a question')
    openQuestions++
    try {
      return await next(e)
    } finally {
      openQuestions--
    }
  }).catch(($, e, next) => next(e))

  // A permission dialog is waiting. Not tool.check: in auto mode the rules
  // often answer "ask" and the classifier then approves with no dialog.
  on('classic.Notification', async ($, e, next) => {
    if (e.notification_type === 'permission_prompt' && openQuestions === 0) void ping($, e.message)
    return next(e)
  })

  on('turn.start', ($, e, next) => {
    if (e.agentId === undefined) sentThisTurn = false
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId === undefined && e.reason === 'answer' && !sentThisTurn)
      void (async () => {
        const mode = await readMode($)
        if (mode === 'all') await send($, 'turn-end', await summarize($, e.answer))
      })()
    return result
  })
}
