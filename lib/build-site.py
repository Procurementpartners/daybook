#!/usr/bin/env python3
"""
Build a local, self-contained browser for Daybook notes.

Reads every day under notes/ and transcripts/ and writes a single
site/index.html that opens straight from disk — no server, no upload.
"""
import json, os, re, html
from datetime import datetime
from pathlib import Path

ROOT = Path(os.environ.get("DBK_ROOT", str(Path.home() / "Daybook")))
OUT = ROOT / "site"
OUT.mkdir(parents=True, exist_ok=True)

line_re = re.compile(r'^`(\d{2}:\d{2}:\d{2})`\s+(.*)$')
meta_re = re.compile(r'^- \*\*(\w+):\*\*\s*(.*)$')

def read_day(day_dir):
    """Parse one day's notes into structured data."""
    meetings, unscheduled = [], []
    for f in sorted(day_dir.glob("*.md")):
        if f.name == "00-index.md":
            continue
        txt = f.read_text(errors="replace")
        lines = txt.splitlines()
        title = lines[0].lstrip("# ").strip() if lines else f.stem
        meta, body, source = {}, [], "mic"
        for ln in lines[1:]:
            m = meta_re.match(ln)
            if m:
                meta[m.group(1).lower()] = m.group(2)
                continue
            if "Source: Microsoft Teams" in ln:
                source = "teams"
            m = line_re.match(ln)
            if m:
                body.append({"t": m.group(1), "s": m.group(2)})
            elif ln.strip() and not ln.startswith(("#", "_", "<", "-")):
                body.append({"t": "", "s": ln.strip()})
        entry = {"title": title, "meta": meta, "lines": body, "source": source}
        (unscheduled if f.name == "unscheduled.md" else meetings).append(entry)
    return meetings + unscheduled

days = {}
notes_root = ROOT / "notes"
if notes_root.exists():
    for d in sorted(notes_root.iterdir(), reverse=True):
        if not d.is_dir() or not re.match(r'\d{4}-\d{2}-\d{2}$', d.name):
            continue
        entries = read_day(d)
        if entries:
            days[d.name] = entries

payload = json.dumps(days, ensure_ascii=False)
total_lines = sum(len(e["lines"]) for day in days.values() for e in day)

HTML = """<title>Daybook</title>
<style>
:root{
  --bg:#faf9f7; --panel:#fff; --ink:#1a1a18; --dim:#6b6a66; --line:#e6e4df;
  --accent:#3d5a80; --teams:#5b5fc7; --mark:#ffe9a8;
  --mono:ui-monospace,SFMono-Regular,"SF Mono",Menlo,monospace;
}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){
  --bg:#16161a; --panel:#1e1e23; --ink:#e8e6e1; --dim:#9b998f; --line:#2e2e35;
  --accent:#8fb3d9; --teams:#a5a8f0; --mark:#5a4a1a;
}}
:root[data-theme="dark"]{
  --bg:#16161a; --panel:#1e1e23; --ink:#e8e6e1; --dim:#9b998f; --line:#2e2e35;
  --accent:#8fb3d9; --teams:#a5a8f0; --mark:#5a4a1a;
}
*{box-sizing:border-box}
body{background:var(--bg);color:var(--ink);font:15px/1.6 ui-sans-serif,-apple-system,system-ui,sans-serif;margin:0}
.wrap{display:grid;grid-template-columns:230px 1fr;min-height:100vh}
aside{border-right:1px solid var(--line);padding:20px 14px;position:sticky;top:0;height:100vh;overflow:auto}
main{padding:28px 32px;max-width:900px;min-width:0}
h1{font-size:17px;margin:0 0 4px;letter-spacing:-.01em}
.sub{color:var(--dim);font-size:12px;margin-bottom:18px}
.daybtn{display:block;width:100%;text-align:left;background:none;border:0;color:var(--ink);
  font:inherit;padding:7px 10px;border-radius:7px;cursor:pointer}
.daybtn:hover{background:var(--line)}
.daybtn.on{background:var(--accent);color:#fff}
.daybtn small{display:block;color:var(--dim);font-size:11px}
.daybtn.on small{color:rgba(255,255,255,.75)}
#q{width:100%;padding:8px 10px;border:1px solid var(--line);border-radius:7px;
  background:var(--panel);color:var(--ink);font:inherit;margin-bottom:14px}
h2{font-size:22px;margin:0 0 20px;letter-spacing:-.02em}
.card{background:var(--panel);border:1px solid var(--line);border-radius:10px;margin-bottom:14px;overflow:hidden}
.hd{padding:14px 16px;cursor:pointer;display:flex;gap:12px;align-items:baseline}
.hd:hover{background:var(--line)}
.time{font:12px/1 var(--mono);color:var(--dim);white-space:nowrap;padding-top:3px}
.ttl{font-weight:600;flex:1;min-width:0}
.tag{font-size:11px;padding:2px 7px;border-radius:99px;border:1px solid var(--line);color:var(--dim);white-space:nowrap}
.tag.teams{color:var(--teams);border-color:var(--teams)}
.who{color:var(--dim);font-size:12px;margin-top:3px;overflow-wrap:anywhere}
.body{display:none;border-top:1px solid var(--line);padding:6px 16px 14px}
.card.open .body{display:block}
.ln{display:flex;gap:12px;padding:3px 0;align-items:baseline}
.ln .t{font:11px/1.6 var(--mono);color:var(--dim);white-space:nowrap}
mark{background:var(--mark);color:inherit;border-radius:3px;padding:0 2px}
.empty{color:var(--dim);font-style:italic;padding:10px 16px}
.none{color:var(--dim);padding:40px 0;text-align:center}
@media(max-width:720px){.wrap{grid-template-columns:1fr}aside{position:static;height:auto;border-right:0;border-bottom:1px solid var(--line)}}
</style>
<div class="wrap">
<aside>
  <h1>Daybook</h1>
  <div class="sub" id="stat"></div>
  <input id="q" placeholder="Search all days…" autocomplete="off">
  <div id="days"></div>
</aside>
<main><div id="view"></div></main>
</div>
<script>
const DAYS = __DATA__;
const keys = Object.keys(DAYS);
let cur = keys[0] || null, q = "";

const esc = s => s.replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
const hi = s => q ? esc(s).replace(new RegExp('('+q.replace(/[.*+?^${}()|[\\]\\\\]/g,'\\\\$&')+')','ig'),'<mark>$1</mark>') : esc(s);
const fmt = d => new Date(d+'T12:00:00').toLocaleDateString(undefined,{weekday:'short',month:'short',day:'numeric'});

function count(day){ return DAYS[day].reduce((n,e)=>n+e.lines.length,0); }

function sidebar(){
  document.getElementById('stat').textContent =
    keys.length + ' day' + (keys.length===1?'':'s') + ' · ' +
    keys.reduce((n,k)=>n+count(k),0).toLocaleString() + ' lines';
  document.getElementById('days').innerHTML = keys.map(k =>
    `<button class="daybtn${k===cur?' on':''}" data-d="${k}">${fmt(k)}
       <small>${count(k)} lines</small></button>`).join('');
  document.querySelectorAll('.daybtn').forEach(b =>
    b.onclick = () => { cur = b.dataset.d; sidebar(); render(); });
}

function render(){
  const v = document.getElementById('view');
  if(!cur){ v.innerHTML = '<div class="none">No notes yet. Record something, then run <code>daybook notes</code>.</div>'; return; }
  const ql = q.toLowerCase();
  const entries = DAYS[cur].map(e => {
    const lines = ql ? e.lines.filter(l => l.s.toLowerCase().includes(ql)) : e.lines;
    return {...e, shown: lines, hit: !ql || lines.length > 0};
  }).filter(e => e.hit);

  v.innerHTML = `<h2>${fmt(cur)}</h2>` + (entries.length ? entries.map((e,i) => {
    const when = e.meta.when || '';
    const who  = e.meta.attendees || '';
    const tag  = e.source === 'teams'
      ? '<span class="tag teams">Teams transcript</span>'
      : (e.shown.length ? `<span class="tag">${e.shown.length} lines</span>` : '<span class="tag">no audio</span>');
    const body = e.shown.length
      ? e.shown.map(l => `<div class="ln"><span class="t">${l.t}</span><span>${hi(l.s)}</span></div>`).join('')
      : '<div class="empty">No audio captured during this window.</div>';
    return `<div class="card${(q||i===0)?' open':''}">
      <div class="hd"><span class="time">${when.split('(')[0].trim()}</span>
        <span class="ttl">${esc(e.title)}${who?`<div class="who">${esc(who)}</div>`:''}</span>${tag}</div>
      <div class="body">${body}</div></div>`;
  }).join('') : '<div class="none">Nothing matches that search on this day.</div>');

  v.querySelectorAll('.hd').forEach(h =>
    h.onclick = () => h.parentElement.classList.toggle('open'));
}

document.getElementById('q').oninput = e => { q = e.target.value.trim(); render(); };
sidebar(); render();
</script>
"""

(OUT / "index.html").write_text(HTML.replace("__DATA__", payload))
print(f"built {OUT / 'index.html'}")
print(f"  {len(days)} day(s), {total_lines:,} transcript lines")
