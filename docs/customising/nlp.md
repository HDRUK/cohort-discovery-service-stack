# NLP rules

The NLP turns a typed question, such as "women over 50 with type 2 diabetes in the last 5 years", into a structured query. It splits the question into parts, recognises ages, sex, deaths and time windows with regular expressions, and matches what's left against the OMOP vocabulary.

Two files control the first part. Both are copies of the NLP's own files at the pinned release, so delete them if you don't need to change anything.

- `customisations/nlp/rules.json`: how a question is split and what the patterns are.
- `customisations/nlp/mappings.json`: words rewritten before matching.

They're mounted into the NLP at `/config/nlp/`, and the NLP restarts when they change. An invalid file stops the NLP from starting; its log says which file and why.

Patterns are Python regular expressions, matched case-insensitively. In JSON, a backslash must be doubled: `\\b`, `\\d+`, `\\s`.

## `mappings.json`

```json
{
  "mappings": [
    { "group": "demographic", "pattern": "\\bmen\\b", "replacement": "MALE" },
    { "group": "demographic", "pattern": "\\bwomen\\b", "replacement": "FEMALE" }
  ]
}
```

Each entry replaces text matching `pattern` with `replacement`, at the step its `group` names. The NLP applies three groups:

| Group | When |
|---|---|
| `normalise` | To each part of the question before it's matched against the vocabulary |
| `demographic` | When looking for sex terms: the shipped file turns words such as "men" and "women" into `MALE` and `FEMALE`, which `demographic_concept_patterns` then picks up |
| `bmi` | When looking for body mass index terms |

Entries in any other group are never applied. An entry can also have `contains`, a list of words of which at least one must be in the text for the entry to apply, and a `warning`, shown to the user when it does.

## `rules.json`

| Key | Shape | What |
|---|---|---|
| `logical_operators` | List of words | The words that join parts of a query. Default `["and", "or"]` |
| `splitters` | List of patterns | Where a question splits into parts: commas, " and ", " who have " and so on |
| `leading_verbs` | List of patterns | Words stripped from the start of a part before matching, such as "diagnosed with" or "received" |
| `age_patterns` | List of `{pattern, op}` | Age rules. The pattern captures the age; `op` is `>`, `>=`, `<`, `<=` or `=`. For example `"aged\\s+over\\s+(\\d+)"` with `">"` |
| `age_overrides` | List of `{pattern, min, max, inclusive}` | Phrases that mean a fixed age range |
| `demographic_age_defaults` | Map of word to `{min, max, inclusive}` | Age ranges for words like "adult" (18 and over) and "child" (0 to 17) |
| `demographic_concept_patterns` | List of patterns | What counts as a sex term once mappings have run |
| `death_patterns` | List of `{pattern, op}` | Phrases about death. `op` `=` means died, `!=` means alive |
| `time_patterns` | List of `{pattern, op}` | Time windows, such as "in the last 5 years" |
| `unsupported_patterns` | Map of name to `{pattern, warning}` | Things the service can't query, such as visits. A match shows the warning to the user |
| `medcat` | Object | Token settings for MedCAT term expansion: minimum token length and stopwords |
| `acronym_rules` | Object | How acronyms are recognised: `min_len`, `max_len`, `token_min_len`, `token_max_len` and `stopwords` |

## Try a change

```bash
curl -s -X POST http://localhost:5001/extract -H 'Content-Type: application/json' \
  -d '{"query": "women over 50 with type 2 diabetes"}'
```

Or type the question into the web app's query builder.
