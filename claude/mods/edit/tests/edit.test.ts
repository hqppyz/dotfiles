import { describe, expect, test } from 'claude-code/testing'

const ok = (exitCode: number) => ({
  value: { exitCode, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
})

describe('/edit', () => {
  test('opens . by default', async ($, on) => {
    const seen: string[][] = []
    on('process.run', (_$, e) => {
      seen.push([...e.argv])
      return ok(0)
    })
    const { text } = await $.command.run({ command: 'edit', args: '' })
    expect(text).toBe('Opened . in the editor.')
    expect(seen[0]?.at(-1)).toBe('.')
  })

  test('passes a path through', async ($, on) => {
    const seen: string[][] = []
    on('process.run', (_$, e) => {
      seen.push([...e.argv])
      return ok(0)
    })
    const { text } = await $.command.run({ command: 'edit', args: ' src/main.ts ' })
    expect(text).toBe('Opened src/main.ts in the editor.')
    expect(seen[0]?.at(-1)).toBe('src/main.ts')
  })

  test('reports a missing EDITOR', async ($, on) => {
    on('process.run', () => ok(3))
    const { text } = await $.command.run({ command: 'edit', args: '' })
    expect(text).toBe('EDITOR is unset.')
  })
})

describe('/edit typeahead', () => {
  const ask = async ($: Parameters<Parameters<typeof test>[1]>[0], text: string) => {
    const start = text.lastIndexOf(' ') + 1
    const r = await $.prompt.autocomplete({ text, cursor: text.length, token: text.slice(start) || ' ', start })
    return r.suggestions.map(s => s.text)
  }

  test('lists dirs first, then files, filtered by prefix', async ($, on) => {
    on('prompt.autocomplete', () => ({ suggestions: [] }))
    on('fs.list', (_$, e) => ({
      value: e.path.endsWith('/src')
        ? [
            { name: 'main.ts', kind: 'file', size: 1, mtimeMs: 0, isLink: false },
            { name: 'lib', kind: 'dir', size: 0, mtimeMs: 0, isLink: false },
            { name: 'other.ts', kind: 'file', size: 1, mtimeMs: 0, isLink: false },
            { name: '.hidden', kind: 'file', size: 1, mtimeMs: 0, isLink: false },
          ]
        : [],
    }))
    expect(await ask($, '/edit src/')).toEqual(['src/lib/', 'src/main.ts', 'src/other.ts'])
    expect(await ask($, '/edit src/m')).toEqual(['src/main.ts'])
    expect(await ask($, '/edit src/.')).toEqual(['src/.hidden'])
    expect(await ask($, 'hello /edit src/')).toEqual([])

  })
})
