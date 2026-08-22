# Dictionary JSON schema

The portable dictionary document is versioned with an integer `schemaVersion`.
Current version is `1`.

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-08-22T12:00:00Z",
  "entries": [
    {
      "id": "UUID",
      "kind": "vocabulary",
      "sourcePhrase": "Claude Code",
      "targetPhrase": null,
      "isEnabled": true,
      "createdAt": "2026-08-22T12:00:00Z",
      "updatedAt": "2026-08-22T12:00:00Z"
    },
    {
      "id": "UUID",
      "kind": "correction",
      "sourcePhrase": "cloud code",
      "targetPhrase": "Claude Code",
      "isEnabled": true,
      "createdAt": "2026-08-22T12:00:00Z",
      "updatedAt": "2026-08-22T12:00:00Z"
    }
  ]
}
```

`kind` is either `vocabulary` or `correction`. Vocabulary has no target. Correction
requires both source and target. IDs and timestamps are stable data, not regenerated
on import. Empty values, unsupported schema versions, and exact duplicate entries
are rejected before a document is committed. Import replacement happens only after
the whole document validates; merge keeps current entries and adds valid imported
entries.

## Matching algorithm

1. Select enabled corrections and sort by descending source length.
2. Split source phrases into word pieces. Between pieces, accept whitespace, a
   hyphen, or no separator.
3. Require a full phrase boundary: the match may not begin or end inside a Unicode
   letter/number/underscore token. Punctuation around a phrase is allowed.
4. Find candidates case-insensitively, choose the longest non-overlapping candidate
   at each position, and replace right-to-left.
5. Never run the matcher again over replacement output. Each replacement creates a
   `CorrectionAudit` with the heard substring and written phrase.

So `cloud code`, `CloudCode`, and `cloud-code` can become `Claude Code`; `cloud`,
`Cloudflare`, and `cloud codebase` remain unchanged. Very short or single-word
patterns produce inline warnings but may be saved deliberately.

Vocabulary is bounded to 24 enabled entries and ranked by relevance to the current
recognition context, with a deterministic recency tie-breaker. Quiet audio does not
create dictionary entries or history items.
