import type { Register } from 'claude-code'

// /edit [path]: opens path (default: `.`, the session's working directory) in $EDITOR.
//
// The editor is detached with setsid, so it outlives the call; a terminal
// editor (vim, nano) gets no TTY here, so only GUI editors work.
// Rows offered per keystroke; directories first, then files.
const MAX_ROWS = 50

const SCRIPT = '[ -n "$EDITOR" ] || exit 3; exec setsid -f $EDITOR "$1" >/dev/null 2>&1'

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'edit',
      description: 'Open a path in $EDITOR',
    })

    return next(e)
  })

  // Typeahead for the path: the entries of the directory typed so far that
  // start with the last segment. Dotfiles only once the segment starts with '.'.
  on('prompt.autocomplete', async ($, e, next) => {
    const m = /^\/edit\s+(\S*)$/.exec(e.text.slice(0, e.cursor))
    if (!m) return next(e)
    const arg = m[1] ?? ''
    const cut = arg.lastIndexOf('/') + 1
    const dir = arg.slice(0, cut)
    const prefix = arg.slice(cut)
    const listed =
      dir === '' ? undefined
      : dir.startsWith('~/') ? `${(await $.env.get('HOME')) ?? ''}${dir.slice(1)}`
      : dir

    let entries
    try {
      entries = await $.fs.list(listed)
    } catch {
      return next(e)
    }
    const rows = await Promise.all(
      entries
        .filter(x => x.name.startsWith(prefix) && (prefix.startsWith('.') || !x.name.startsWith('.')))
        .map(async x => {
          const kind = x.isLink
            ? await $.fs.stat(`${listed ?? '.'}/${x.name}`).then(st => st.kind, () => x.kind)
            : x.kind
          return { name: x.name, isDir: kind === 'dir' }
        }),
    )
    rows.sort((a, b) => Number(b.isDir) - Number(a.isDir) || a.name.localeCompare(b.name))
    const suggestions = rows.slice(0, MAX_ROWS).map(r => ({
      text: `${dir}${r.name}${r.isDir ? '/' : ''}`,
      label: `${r.name}${r.isDir ? '/' : ''}`,
    }))

    return { suggestions: [...suggestions, ...(await next(e)).suggestions] }
  })

  on('command.run', { command: 'edit' }, async ($, e) => {
    const target = e.args.trim() || '.'
    const { exitCode, stderr } = await $.process.run(['sh', '-c', SCRIPT, 'sh', target])
    if (exitCode === 3) return { text: 'EDITOR is unset.' }
    if (exitCode !== 0) return { text: `Editor failed (${exitCode}): ${stderr.trim()}` }

    return { text: `Opened ${target} in the editor.` }
  })
}
