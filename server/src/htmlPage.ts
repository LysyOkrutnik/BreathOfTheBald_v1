/// Minimal, self-contained HTML page template — no template engine in this
/// project. Shared by the auth verification/reset pages and the /admin
/// panel so both stay visually consistent without duplicating the same
/// inline stylesheet. `wide` widens the layout and left-aligns content for
/// panel pages (tables, forms) instead of the narrow centered auth cards.
export function htmlPage(title: string, bodyHtml: string, opts: { wide?: boolean } = {}): string {
  const maxWidth = opts.wide ? '960px' : '400px';
  const align = opts.wide ? 'left' : 'center';
  return `<!doctype html><html lang="pl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>
body{background:#040D14;color:#F5F5F5;font-family:system-ui,-apple-system,sans-serif;
display:flex;min-height:100vh;align-items:${opts.wide ? 'flex-start' : 'center'};justify-content:center;margin:0;padding:24px;box-sizing:border-box}
.card{max-width:${maxWidth};width:100%;text-align:${align}}
h1{font-size:20px;font-weight:600;margin-bottom:12px}
h2{font-size:16px;font-weight:600;margin:24px 0 8px}
p{color:#B0BEC5;font-size:14px;line-height:1.5}
input,select,textarea{width:100%;padding:12px;margin:8px 0;border-radius:8px;border:1px solid #444;
background:#111;color:#F5F5F5;box-sizing:border-box;font-size:14px;font-family:inherit}
button,.btn{display:inline-block;padding:10px 16px;margin-top:8px;border-radius:8px;border:none;
background:#81C784;color:#000;font-weight:700;font-size:14px;cursor:pointer;text-decoration:none}
.btn.danger{background:#E57373}
.btn.secondary{background:#333;color:#F5F5F5}
.err{color:#E57373}
nav{display:flex;gap:16px;margin-bottom:24px;border-bottom:1px solid #222;padding-bottom:12px;flex-wrap:wrap}
nav a{color:#B0BEC5;text-decoration:none;font-size:14px}
nav a.active{color:#81C784;font-weight:600}
table{width:100%;border-collapse:collapse;margin:12px 0;font-size:14px}
th,td{text-align:left;padding:8px;border-bottom:1px solid #222}
th{color:#B0BEC5;font-weight:600}
.muted{color:#B0BEC5;font-size:13px}
form.inline{display:inline}
</style></head><body><div class="card">${bodyHtml}</div></body></html>`;
}
