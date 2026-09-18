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

def md_to_html(md):
    """Minimal markdown -> HTML for summaries: headings, bullets, numbers, bold, code."""
    import html as _h
    out, in_ul, in_ol = [], False, False
    def close():
        nonlocal in_ul, in_ol
        if in_ul: out.append("</ul>"); in_ul = False
        if in_ol: out.append("</ol>"); in_ol = False
    for raw in md.splitlines():
        ln = raw.rstrip()
        if not ln.strip():
            close(); continue
        esc = _h.escape(ln)
        esc = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', esc)
        esc = re.sub(r'`(.+?)`', r'<code>\1</code>', esc)
        m = re.match(r'^(#{1,4})\s+(.*)$', esc)
        if m:
            close(); lvl = min(len(m.group(1)) + 2, 6)
            out.append(f"<h{lvl}>{m.group(2)}</h{lvl}>"); continue
        m = re.match(r'^\s*(?:[-*\u2022])\s+(.*)$', esc)
        if m:
            if in_ol: out.append("</ol>"); in_ol = False
            if not in_ul: out.append("<ul>"); in_ul = True
            out.append(f"<li>{m.group(1)}</li>"); continue
        m = re.match(r'^\s*\d+[.)]\s+(.*)$', esc)
        if m:
            if in_ul: out.append("</ul>"); in_ul = False
            if not in_ol: out.append("<ol>"); in_ol = True
            out.append(f"<li>{m.group(1)}</li>"); continue
        close(); out.append(f"<p>{esc}</p>")
    close()
    return "\n".join(out)


def read_day(day_dir):
    """Parse one day's notes into structured data."""
    meetings, unscheduled = [], []
    sum_dir = ROOT / "summaries" / day_dir.name
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
        sf = sum_dir / f.name
        summary = md_to_html(sf.read_text(errors="replace")) if sf.exists() else ""
        entry = {"title": title, "meta": meta, "lines": body,
                 "source": source, "summary": summary}
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

HTML = r"""<title>Daybook</title>
<style>
:root{
  --bg:#faf9f7; --panel:#fff; --rail:#f3f1ed; --ink:#1a1a18; --dim:#6b6a66; --line:#e6e4df;
  --accent:#3d5a80; --teams:#5b5fc7; --mark:#ffe9a8;
  --mono:ui-monospace,SFMono-Regular,"SF Mono",Menlo,monospace;
}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){
  --bg:#141417; --panel:#1b1b20; --rail:#17171b; --ink:#e8e6e1; --dim:#9b998f; --line:#2b2b32;
  --accent:#8fb3d9; --teams:#a5a8f0; --mark:#5a4a1a;
}}
:root[data-theme="dark"]{
  --bg:#141417; --panel:#1b1b20; --rail:#17171b; --ink:#e8e6e1; --dim:#9b998f; --line:#2b2b32;
  --accent:#8fb3d9; --teams:#a5a8f0; --mark:#5a4a1a;
}
*{box-sizing:border-box}
html,body{height:100%}
body{background:var(--bg);color:var(--ink);margin:0;
  font:15px/1.6 ui-sans-serif,-apple-system,system-ui,sans-serif;
  display:flex;flex-direction:column;overflow:hidden}

/* ---- top bar: dates ---- */
header{border-bottom:1px solid var(--line);background:var(--rail);flex:none}
.brand{display:flex;align-items:baseline;gap:12px;padding:12px 20px 0}
.brand h1{font-size:15px;margin:0;letter-spacing:-.01em}
.brand .stat{color:var(--dim);font-size:12px}
.brand #q{margin-left:auto;width:260px;padding:6px 10px;border:1px solid var(--line);
  border-radius:7px;background:var(--panel);color:var(--ink);font:inherit;font-size:13px}
.dates{display:flex;gap:6px;padding:10px 20px;overflow-x:auto}
.datebtn{flex:none;background:none;border:1px solid transparent;color:var(--ink);
  font:inherit;font-size:13px;padding:6px 12px;border-radius:8px;cursor:pointer;white-space:nowrap}
.datebtn:hover{background:var(--line)}
.datebtn.on{background:var(--accent);color:#fff}
.datebtn small{display:block;font-size:11px;color:var(--dim)}
.datebtn.on small{color:rgba(255,255,255,.8)}

/* ---- body: meetings | transcript ---- */
.cols{display:grid;grid-template-columns:300px 1fr;flex:1;min-height:0}
nav{border-right:1px solid var(--line);overflow-y:auto;padding:10px}
.mtg{width:100%;text-align:left;background:none;border:0;color:var(--ink);font:inherit;
  padding:9px 11px;border-radius:8px;cursor:pointer;display:block;margin-bottom:2px}
.mtg:hover{background:var(--line)}
.mtg.on{background:var(--accent);color:#fff}
.mtg .t{font:11px/1.4 var(--mono);color:var(--dim)}
.mtg.on .t{color:rgba(255,255,255,.8)}
.mtg .n{font-weight:600;font-size:13.5px;margin:1px 0 2px;overflow-wrap:anywhere}
.mtg .c{font-size:11px;color:var(--dim)}
.mtg.on .c{color:rgba(255,255,255,.75)}
.mtg .c.teams{color:var(--teams);font-weight:600}
.mtg.on .c.teams{color:#fff}
.mtg.empty .n{font-weight:500;color:var(--dim)}
.mtg.on.empty .n{color:rgba(255,255,255,.8)}

main{overflow-y:auto;padding:22px 30px}
.mhead{margin-bottom:18px;padding-bottom:14px;border-bottom:1px solid var(--line)}
.mhead h2{font-size:21px;margin:0 0 6px;letter-spacing:-.02em}
.mhead .meta{color:var(--dim);font-size:12.5px;overflow-wrap:anywhere}
.src{display:inline-block;font-size:11px;padding:2px 8px;border-radius:99px;
  border:1px solid var(--line);color:var(--dim);margin-top:8px}
.src.teams{color:var(--teams);border-color:var(--teams)}
.summary{background:var(--panel);border:1px solid var(--line);border-radius:10px;
  padding:16px 20px;margin-bottom:22px}
.summary h3,.summary h4,.summary h5{margin:16px 0 6px;font-size:13px;letter-spacing:.04em;
  text-transform:uppercase;color:var(--accent)}
.summary h3:first-child,.summary h4:first-child,.summary h5:first-child{margin-top:0}
.summary p{margin:6px 0}
.summary ul,.summary ol{margin:6px 0;padding-left:22px}
.summary li{margin:3px 0}
.summary code{font:12.5px var(--mono);background:var(--rail);padding:1px 5px;border-radius:4px}
.divider{display:flex;align-items:center;gap:12px;color:var(--dim);font-size:11px;
  letter-spacing:.08em;text-transform:uppercase;margin:0 0 10px}
.divider::after{content:"";flex:1;height:1px;background:var(--line)}
.nosum{color:var(--dim);font-size:12.5px;font-style:italic;margin-bottom:20px}
.ln{display:flex;gap:14px;padding:3px 0;align-items:baseline}
.ln .t{font:11px/1.7 var(--mono);color:var(--dim);white-space:nowrap}
mark{background:var(--mark);color:inherit;border-radius:3px;padding:0 2px}
.none{color:var(--dim);font-style:italic;padding:30px 0;text-align:center}
@media(max-width:760px){
  .cols{grid-template-columns:1fr;grid-template-rows:auto 1fr}
  nav{border-right:0;border-bottom:1px solid var(--line);max-height:180px}
  .brand #q{width:150px}
}
</style>
<header>
  <div class="brand">
    <h1>Daybook</h1><span class="stat" id="stat"></span>
    <input id="q" placeholder="Search all days…" autocomplete="off">
  </div>
  <div class="dates" id="dates"></div>
</header>
<div class="cols">
  <nav id="mtgs"></nav>
  <main id="view"></main>
</div>
<script>
const DAYS = __DATA__;
const keys = Object.keys(DAYS);
let cur = keys[0] || null, sel = 0, q = "";

const esc = s => s.replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
const hi = s => q ? esc(s).replace(new RegExp('('+q.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+')','ig'),'<mark>$1</mark>') : esc(s);
const fmt = d => new Date(d+'T12:00:00').toLocaleDateString(undefined,{weekday:'short',month:'short',day:'numeric'});
const count = day => DAYS[day].reduce((n,e)=>n+e.lines.length,0);

// lines of one entry that match the current query
function shown(e){
  if(!q) return e.lines;
  const ql = q.toLowerCase();
  return e.lines.filter(l => l.s.toLowerCase().includes(ql));
}

function topbar(){
  document.getElementById('stat').textContent =
    keys.length + ' day' + (keys.length===1?'':'s') + ' · ' +
    keys.reduce((n,k)=>n+count(k),0).toLocaleString() + ' lines';
  document.getElementById('dates').innerHTML = keys.map(k =>
    `<button class="datebtn${k===cur?' on':''}" data-d="${k}">${fmt(k)}
       <small>${count(k).toLocaleString()} lines</small></button>`).join('');
  document.querySelectorAll('.datebtn').forEach(b =>
    b.onclick = () => { cur = b.dataset.d; sel = 0; render(); });
}

function render(){
  topbar();
  const nav = document.getElementById('mtgs'), view = document.getElementById('view');
  if(!cur){ nav.innerHTML=''; view.innerHTML='<div class="none">No notes yet.</div>'; return; }

  let list = DAYS[cur].map((e,i) => ({e, i, hits: shown(e)}));
  if(q) list = list.filter(x => x.hits.length > 0);

  nav.innerHTML = list.length ? list.map(({e,i,hits}) => {
    const when = (e.meta.when||'').split('(')[0].trim();
    const tag  = e.source==='teams' ? '<span class="c teams">Teams transcript</span>'
               : `<span class="c">${hits.length} line${hits.length===1?'':'s'}${e.summary?' · summarised':''}</span>`;
    return `<button class="mtg${i===sel?' on':''}${hits.length?'':' empty'}" data-i="${i}">
      <span class="t">${when||'&nbsp;'}</span>
      <span class="n">${esc(e.title)}</span>${tag}</button>`;
  }).join('') : '<div class="none">No matches</div>';

  nav.querySelectorAll('.mtg').forEach(b =>
    b.onclick = () => { sel = +b.dataset.i; render(); });

  if(!list.some(x => x.i === sel)) sel = list.length ? list[0].i : -1;
  const e = sel >= 0 ? DAYS[cur][sel] : null;
  if(!e){ view.innerHTML = '<div class="none">Nothing to show</div>'; return; }

  const hits = shown(e);
  const att = e.meta.attendees ? `<div class="meta">${esc(e.meta.attendees)}</div>` : '';
  const org = e.meta.organizer ? `<div class="meta">Organiser: ${esc(e.meta.organizer)}</div>` : '';
  const src = e.source==='teams'
    ? '<span class="src teams">Microsoft Teams — speaker-attributed</span>'
    : '<span class="src">Local microphone — no speaker labels</span>';

  const summary = e.summary
    ? `<div class="summary">${e.summary}</div>`
    : (e.lines.length ? '<div class="nosum">No summary yet for this meeting.</div>' : '');

  const body = hits.length
    ? `<div class="divider">Transcript · ${hits.length} line${hits.length===1?'':'s'}</div>` +
      hits.map(l => `<div class="ln"><span class="t">${l.t}</span><span>${hi(l.s)}</span></div>`).join('')
    : '<div class="none">No audio captured during this window.</div>';

  view.innerHTML = `<div class="mhead">
      <h2>${esc(e.title)}</h2>
      <div class="meta">${esc(e.meta.when||'')}</div>${org}${att}${src}
    </div>` + summary + body;
  view.scrollTop = 0;
}

document.getElementById('q').oninput = e => { q = e.target.value.trim(); render(); };
render();
</script>
"""

(OUT / "index.html").write_text(HTML.replace("__DATA__", payload))
print(f"built {OUT / 'index.html'}")
print(f"  {len(days)} day(s), {total_lines:,} transcript lines")
