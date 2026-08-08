import re
from pathlib import Path

ROOT = Path(__file__).parent.parent


def test_installer_has_set_e():
    src = (ROOT / "install.sh").read_text()
    assert re.search(r"^set -[a-zA-Z]*e", src, re.M), "install.sh debe usar set -e"


def test_no_http_plain_downloads():
    src = (ROOT / "install.sh").read_text()
    # Ningun curl/descarga debe apuntar a http:// (solo https)
    bad = [ln for ln in src.splitlines() if "curl" in ln and "http://" in ln]
    assert not bad, f"curl con http:// encontrado: {bad}"


def test_sources_https():
    src = (ROOT / "install.sh").read_text()
    urls = re.findall(r'"(https?://[^"]+)"', src)
    bad = [u for u in urls if u.startswith("http://")]
    assert not bad, f"URLs http:// en install.sh: {bad}"
