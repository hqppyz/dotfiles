import { describe, expect, test } from 'claude-code/testing'

describe('/notif', () => {
  test('rejects bad arguments with the usage line', async $ => {
    for (const args of ['bogus', 'set', 'set ask', 'ask now', 'send']) {
      const { text } = await $.command.run({ command: 'notif', args })
      expect(text).toBe('usage: /notif [off|ask|all | send <text>]')
    }
  })
})

describe('/notif typeahead', () => {
  const ask = async ($: Parameters<Parameters<typeof test>[1]>[0], text: string) =>
    (await $.prompt.autocomplete({ text, cursor: text.length, token: text.split(' ').pop() ?? '', start: text.lastIndexOf(' ') + 1 })).suggestions.map(r => r.text)

  test('offers the modes and send', async ($, on) => {
    on('prompt.autocomplete', () => ({ suggestions: [] }))
    expect(await ask($, '/notif s')).toEqual(['send'])
    expect(await ask($, '/notif a')).toEqual(['ask', 'all'])
    expect(await ask($, '/notif o')).toEqual(['off'])
    expect(await ask($, '/notif send hi')).toEqual([])
    expect(await ask($, 'hello /notif s')).toEqual([])
  })
})
