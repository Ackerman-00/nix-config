---
name: arxiv
description: "Search arXiv papers by keyword, author, category, or ID over the public arXiv API, and pull citation counts and related papers from Semantic Scholar. Works on Linux with curl and the bundled stdlib Python helper."
---

# arXiv research

Search and retrieve academic papers from arXiv's free API. No key, no
dependencies: `curl` and the bundled Python script are enough.

## Quick reference

| Action | Command |
|---|---|
| Search | `curl "http://export.arxiv.org/api/query?search_query=all:QUERY&max_results=5"` |
| By ID | `curl "http://export.arxiv.org/api/query?id_list=2402.03300"` |
| Abstract page | read `https://arxiv.org/abs/2402.03300` |
| Full paper PDF | read `https://arxiv.org/pdf/2402.03300` |

Use `https://export.arxiv.org/api/query` when the plain host redirects badly;
both work.

## Searching

```bash
curl -s "https://export.arxiv.org/api/query?search_query=all:GRPO+reinforcement+learning&max_results=5"
```

Clean output (parse the Atom XML):

```bash
curl -s "https://export.arxiv.org/api/query?search_query=all:GRPO+reinforcement+learning&max_results=5&sortBy=submittedDate&sortOrder=descending" | python3 -c "
import sys, xml.etree.ElementTree as ET
ns = {'a': 'http://www.w3.org/2005/Atom'}
root = ET.parse(sys.stdin).getroot()
for i, entry in enumerate(root.findall('a:entry', ns)):
    title = entry.find('a:title', ns).text.strip().replace('\n', ' ')
    arxiv_id = entry.find('a:id', ns).text.strip().split('/abs/')[-1]
    published = entry.find('a:published', ns).text[:10]
    authors = ', '.join(a.find('a:name', ns).text for a in entry.findall('a:author', ns))
    summary = entry.find('a:summary', ns).text.strip()[:200]
    cats = ', '.join(c.get('term') for c in entry.findall('a:category', ns))
    print(f'{i+1}. [{arxiv_id}] {title}')
    print(f'   Authors: {authors}')
    print(f'   Published: {published} | Categories: {cats}')
    print(f'   Abstract: {summary}...')
    print(f'   PDF: https://arxiv.org/pdf/{arxiv_id}')
    print()
"
```

## Query syntax

| Prefix | Searches | Example |
|---|---|---|
| `all:` | all fields | `all:transformer+attention` |
| `ti:` | title | `ti:large+language+models` |
| `au:` | author | `au:vaswani` |
| `abs:` | abstract | `abs:reinforcement+learning` |
| `cat:` | category | `cat:cs.AI` |
| `co:` | comment | `co:accepted+NeurIPS` |

Boolean:

```
all:transformer+attention          # AND (the default when joining with +)
all:GPT+OR+all:BERT                # OR
all:language+model+ANDNOT+all:vision
ti:"chain+of+thought"              # exact phrase
au:hinton+AND+cat:cs.LG
```

## Sorting and pagination

| Parameter | Options |
|---|---|
| `sortBy` | `relevance`, `lastUpdatedDate`, `submittedDate` |
| `sortOrder` | `ascending`, `descending` |
| `start` | result offset (0-based) |
| `max_results` | number of results (default 10) |

```bash
curl -s "https://export.arxiv.org/api/query?search_query=cat:cs.AI&sortBy=submittedDate&sortOrder=descending&max_results=10"
```

## Fetching specific papers

```bash
curl -s "https://export.arxiv.org/api/query?id_list=2402.03300"
curl -s "https://export.arxiv.org/api/query?id_list=2402.03300,2401.12345,2403.00001"
```

## Helper script

`scripts/search_arxiv.py` handles the XML parsing and prints clean output.
Stdlib only.

```bash
python3 scripts/search_arxiv.py "GRPO reinforcement learning"
python3 scripts/search_arxiv.py "transformer attention" --max 10 --sort date
python3 scripts/search_arxiv.py --author "Yann LeCun" --max 5
python3 scripts/search_arxiv.py --category cs.AI --sort date
python3 scripts/search_arxiv.py --id 2402.03300
python3 scripts/search_arxiv.py --id 2402.03300,2401.12345
```

## BibTeX

```bash
curl -s "https://export.arxiv.org/api/query?id_list=1706.03762" | python3 -c "
import sys, xml.etree.ElementTree as ET
ns = {'a': 'http://www.w3.org/2005/Atom', 'arxiv': 'http://arxiv.org/schemas/atom'}
root = ET.parse(sys.stdin).getroot()
entry = root.find('a:entry', ns)
if entry is None: sys.exit('Paper not found')
title = entry.find('a:title', ns).text.strip().replace('\n', ' ')
authors = ' and '.join(a.find('a:name', ns).text for a in entry.findall('a:author', ns))
year = entry.find('a:published', ns).text[:4]
raw_id = entry.find('a:id', ns).text.strip().split('/abs/')[-1]
cat = entry.find('arxiv:primary_category', ns)
primary = cat.get('term') if cat is not None else 'cs.LG'
last_name = entry.find('a:author', ns).find('a:name', ns).text.split()[-1]
print(f'@article{{{last_name}{year}_{raw_id.replace(\".\", \"\")},')
print(f'  title     = {{{title}}},')
print(f'  author    = {{{authors}}},')
print(f'  year      = {{{year}}},')
print(f'  eprint    = {{{raw_id}}},')
print(f'  archivePrefix = {{arXiv}},')
print(f'  primaryClass  = {{{primary}}},')
print(f'  url       = {{https://arxiv.org/abs/{raw_id}}}')
print('}')
"
```

## Reading a paper

- Abstract page: read `https://arxiv.org/abs/<id>` with the `webfetch` tool.
- Full PDF: read `https://arxiv.org/pdf/<id>`. For a local PDF, use the
  `read` tool on the path.
- HTML version when available: `https://arxiv.org/html/<id>`.

## Semantic Scholar (citations and related work)

arXiv has no citation graph. Use the Semantic Scholar API for that: free, no
key for basic use.

```bash
# paper details
curl -s "https://api.semanticscholar.org/graph/v1/paper/arXiv:2402.03300?fields=title,authors,citationCount,referenceCount,influentialCitationCount,year,abstract" | python3 -m json.tool

# who cited it
curl -s "https://api.semanticscholar.org/graph/v1/paper/arXiv:2402.03300/citations?fields=title,authors,year,citationCount&limit=10" | python3 -m json.tool

# what it cites
curl -s "https://api.semanticscholar.org/graph/v1/paper/arXiv:2402.03300/references?fields=title,authors,year,citationCount&limit=10" | python3 -m json.tool

# search
curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=GRPO+reinforcement+learning&limit=5&fields=title,authors,year,citationCount,externalIds" | python3 -m json.tool

# author profile
curl -s "https://api.semanticscholar.org/graph/v1/author/search?query=Yann+LeCun&fields=name,hIndex,citationCount,paperCount" | python3 -m json.tool
```

Recommendations:

```bash
curl -s -X POST "https://api.semanticscholar.org/recommendations/v1/papers/" \
  -H "Content-Type: application/json" \
  -d '{"positivePaperIds": ["arXiv:2402.03300"], "negativePaperIds": []}' | python3 -m json.tool
```

## Common categories

| Category | Field |
|---|---|
| `cs.AI` | Artificial Intelligence |
| `cs.CL` | Computation and Language (NLP) |
| `cs.CV` | Computer Vision |
| `cs.LG` | Machine Learning |
| `cs.CR` | Cryptography and Security |
| `stat.ML` | Machine Learning (Statistics) |
| `math.OC` | Optimization and Control |
| `physics.comp-ph` | Computational Physics |

Full list: <https://arxiv.org/category_taxonomy>

## Rate limits

| API | Rate | Auth |
|---|---|---|
| arXiv | ~1 request / 3 seconds | none |
| Semantic Scholar | 1 request / second | none (100/s with a key) |

## Notes

- arXiv returns Atom XML. Use the helper script or the parsing snippet.
- Semantic Scholar returns JSON; pipe through `python3 -m json.tool`.
- ID formats: old (`hep-th/0601001`) versus new (`2402.03300`).
- PDF: `https://arxiv.org/pdf/<id>`. Abstract: `https://arxiv.org/abs/<id>`.
- **ID versioning**: `arxiv.org/abs/1706.03762` always resolves to the latest
  version; `arxiv.org/abs/1706.03762v1` pins one. Preserve the version you
  actually read in citations. The API `<id>` field returns the versioned URL.
- **Withdrawn papers**: the `<summary>` then carries a withdrawal notice.
  Check the summary before treating a result as valid.
