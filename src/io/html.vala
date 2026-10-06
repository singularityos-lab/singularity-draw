namespace Singularity.Apps.Draw {

    public class HtmlExport {
        private static string esc (string s) {
            return XmlWriter.escape (s, true);
        }

        public static string write (Document doc) {
            doc.link_backgrounds ();
            var pages = doc.foreground_pages ();
            if (pages.size == 0) pages = doc.pages;
            string title = doc.title != "" ? doc.title : (doc.path != null ? Path.get_basename (doc.path) : _("Drawing"));
            var sb = new StringBuilder ();
            sb.append ("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n");
            sb.append ("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n");
            sb.append ("<meta name=\"generator\" content=\"Singularity Draw\">\n");
            sb.append ("<title>%s</title>\n".printf (esc (title)));
            sb.append ("<style>\n");
            sb.append ("body{margin:0;font-family:sans-serif;background:#eef0f3;color:#1e1e1e}\n");
            sb.append ("header{display:flex;flex-wrap:wrap;gap:8px;align-items:center;padding:10px 16px;background:#fff;border-bottom:1px solid #d8dce1;position:sticky;top:0;z-index:2}\n");
            sb.append ("header h1{font-size:16px;margin:0 12px 0 0}\n");
            sb.append ("nav button{border:1px solid #c9ced6;background:#f7f8fa;border-radius:8px;padding:5px 12px;cursor:pointer;font:inherit}\n");
            sb.append ("nav button[aria-selected=true]{background:#3a6ea5;color:#fff;border-color:#3a6ea5}\n");
            sb.append ("main{display:flex;gap:16px;padding:16px;align-items:flex-start}\n");
            sb.append (".page{display:none;background:#fff;box-shadow:0 2px 10px rgba(0,0,0,.15);overflow:auto;max-width:100%}\n");
            sb.append (".page.active{display:block}\n.page svg{display:block;max-width:100%;height:auto}\n");
            sb.append ("aside{min-width:220px;max-width:320px;background:#fff;border-radius:10px;padding:12px;box-shadow:0 1px 4px rgba(0,0,0,.1);font-size:13px}\n");
            sb.append ("aside table{border-collapse:collapse;width:100%}aside td{border-top:1px solid #eee;padding:4px;vertical-align:top}\n");
            sb.append ("[data-shape]{cursor:pointer}\n");
            sb.append ("</style>\n</head>\n<body>\n<header><h1>%s</h1><nav role=\"tablist\">\n".printf (esc (title)));
            for (int i = 0; i < pages.size; i++) {
                sb.append ("<button role=\"tab\" data-target=\"page-%d\" aria-selected=\"%s\">%s</button>\n".printf (i + 1, i == 0 ? "true" : "false", esc (pages[i].name)));
            }
            sb.append ("</nav></header>\n<main>\n<div>\n");
            var data = new StringBuilder ();
            data.append ("{");
            bool first_data = true;
            for (int i = 0; i < pages.size; i++) {
                var p = pages[i];
                string svg = SvgWriter.write_page (p, SvgWriter.page_area (p), true);
                if (svg.has_prefix ("<?xml")) svg = svg.substring (svg.index_of ("?>") + 2);
                sb.append ("<section class=\"page%s\" id=\"page-%d\" data-name=\"%s\" role=\"tabpanel\" aria-label=\"%s\">\n".printf (i == 0 ? " active" : "", i + 1, esc (p.name), esc (p.name)));
                sb.append (svg);
                sb.append ("\n</section>\n");
                foreach (var it in p.all_items ()) {
                    if (it.fields.size == 0) continue;
                    if (!first_data) data.append (",");
                    first_data = false;
                    data.append ("\"%s\":{".printf (json (it.id)));
                    for (int f = 0; f < it.fields.size; f++) {
                        if (f > 0) data.append (",");
                        data.append ("\"%s\":\"%s\"".printf (json (it.fields[f].key), json (it.fields[f].value)));
                    }
                    data.append ("}");
                }
            }
            data.append ("}");
            sb.append ("</div>\n<aside aria-live=\"polite\"><strong>%s</strong><div id=\"details\">%s</div></aside>\n".printf (esc (_("Shape Data")), esc (_("Select a shape to see its data."))));
            sb.append ("</main>\n<script>\n");
            sb.append ("const DATA=%s;\n".printf (data.str));
            sb.append ("function show(id){document.querySelectorAll('.page').forEach(p=>p.classList.toggle('active',p.id===id));document.querySelectorAll('nav button').forEach(b=>b.setAttribute('aria-selected',b.dataset.target===id));}\n");
            sb.append ("document.querySelectorAll('nav button').forEach(b=>b.addEventListener('click',()=>show(b.dataset.target)));\n");
            sb.append ("document.querySelectorAll('a[data-page]').forEach(a=>a.addEventListener('click',e=>{e.preventDefault();const s=[...document.querySelectorAll('.page')].find(p=>p.dataset.name===a.dataset.page);if(s)show(s.id);}));\n");
            sb.append ("document.querySelectorAll('svg g[id]').forEach(g=>{if(DATA[g.id]){g.setAttribute('data-shape','');g.addEventListener('click',e=>{e.stopPropagation();const d=DATA[g.id];const t=document.createElement('table');for(const k in d){const r=t.insertRow();r.insertCell().textContent=k;r.insertCell().textContent=d[k];}const box=document.getElementById('details');box.replaceChildren(t);});}});\n");
            sb.append ("</script>\n</body>\n</html>\n");
            return sb.str;
        }

        private static string json (string s) {
            var sb = new StringBuilder ();
            unichar c;
            int i = 0;
            while (s.get_next_char (ref i, out c)) {
                switch (c) {
                    case '"': sb.append ("\\\""); break;
                    case '\\': sb.append ("\\\\"); break;
                    case '\n': sb.append ("\\n"); break;
                    case '\r': break;
                    case '<': sb.append ("\\u003c"); break;
                    default:
                        if (c < 0x20) sb.append ("\\u%04x".printf ((uint) c));
                        else sb.append_unichar (c);
                        break;
                }
            }
            return sb.str;
        }
    }
}
