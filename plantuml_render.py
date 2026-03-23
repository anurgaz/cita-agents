"""Custom fence format for PlantUML rendering via pymdownx.superfences."""
import subprocess
import hashlib
import os


def fenced_plantuml_format(source, language, css_class, options, md, **kwargs):
    h = hashlib.md5(source.encode()).hexdigest()
    cache_dir = "/tmp/plantuml_cache"
    os.makedirs(cache_dir, exist_ok=True)
    svg_path = f"{cache_dir}/{h}.svg"

    if not os.path.exists(svg_path):
        try:
            result = subprocess.run(
                ["plantuml", "-tsvg", "-pipe"],
                input=source.encode(),
                capture_output=True,
                timeout=30,
            )
            if result.returncode == 0:
                with open(svg_path, "wb") as f:
                    f.write(result.stdout)
            else:
                err = result.stderr.decode(errors="replace")
                return f'<pre class="plantuml-error">{err}</pre>'
        except Exception as e:
            return f'<pre class="plantuml-error">{e}</pre>'

    with open(svg_path) as f:
        svg = f.read()

    # Strip XML declaration if present
    if svg.startswith("<?xml"):
        svg = svg[svg.index("?>")+2:].strip()

    return f'<div class="plantuml">{svg}</div>'
