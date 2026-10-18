#!/usr/bin/env python3
"""
Build "Genus Purchase Orders.html" - one self-contained file.

    cd apps/po-system/src
    npm install
    npx esbuild sbentry.js --bundle --format=iife --global-name=supabase \
        --platform=browser --target=es2019 --minify --outfile=build/supabase.bundle.js
    python3 build.py

Everything is inlined: the two libraries, the logo, and the Supabase project
settings. The page needs no CDN, which matters because it is opened from a
folder rather than served.

Why supabase-js is re-bundled rather than taken from dist/umd: that build is
webpack's, and webpack works out its own publicPath from document.currentScript.src.
An inline script has no src, so it throws "Automatic publicPath is not supported
in this browser" before the client is ever created. esbuild's IIFE has no such
idea and inlines cleanly.

The anon key below is public by design - every rule that matters is enforced in
the database. See AGENTS.md.
"""
import base64
import pathlib
import re

HERE = pathlib.Path(__file__).parent
OUT = HERE.parent / 'Genus Purchase Orders.html'

SB_URL = 'https://vozefpljljmneeomphef.supabase.co'
SB_ANON = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvemVmcGxqbGptbm'
           'Vlb21waGVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgzNjkyOTMsImV4cCI6MjEwMzk0NTI5M30.'
           'E_FQPsqejlJJoU-TiTq1LFbTMhrczZTZnNX3dMu89CU')

LIBS = [
    HERE / 'build' / 'supabase.bundle.js',
    HERE / 'node_modules' / 'jspdf' / 'dist' / 'jspdf.umd.min.js',
    HERE / 'node_modules' / 'jspdf-autotable' / 'dist' / 'jspdf.plugin.autotable.min.js',
]


def bundle() -> str:
    parts = []
    for path in LIBS:
        if not path.exists():
            raise SystemExit('Missing ' + str(path) + ' - see the header of this file.')
        text = path.read_text(encoding='utf-8')
        #  The maps are not shipped, so the comments only produce 404s.
        text = re.sub(r'(?m)^//# sourceMappingURL=.*$', '', text)
        text = re.sub(r'/\*# sourceMappingURL=[^*]*\*/', '', text)
        #  A literal closing script tag would end the block early.
        if '</script' in text.lower().replace('<\\/script', ''):
            raise SystemExit('A closing script tag appears in ' + path.name)
        parts.append('/* ---- ' + path.name + ' ---- */\n' + text)
    return '<script>\n' + '\n;\n'.join(parts) + '\n</' + 'script>\n'


def main() -> None:
    html = (HERE / 'app.html').read_text(encoding='utf-8')
    html = html.replace('LOGO_PDF_SRC', 'data:image/jpeg;base64,' +
                        (HERE / 'assets' / 'logo_pdf.b64').read_text().strip())
    html = html.replace('LOGO_SRC', 'data:image/png;base64,' +
                        (HERE / 'assets' / 'logo_web.b64').read_text().strip())
    html = html.replace('SB_URL_HERE', SB_URL)
    html = html.replace('SB_ANON_KEY', SB_ANON)

    anchor = ('<script>\n/* ================================================================\n'
              '   Genus Purchase Orders')
    if anchor not in html:
        raise SystemExit('Could not find where to put the libraries in app.html.')
    html = html.replace(anchor, bundle() + anchor, 1)

    OUT.write_text(html, encoding='utf-8')
    print('Wrote ' + OUT.name + ' - ' + str(round(len(html) / 1024)) + ' KB')


if __name__ == '__main__':
    main()
