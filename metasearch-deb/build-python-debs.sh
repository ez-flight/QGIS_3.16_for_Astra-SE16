#!/bin/bash
# Самостоятельная сборка python3-owslib/nbformat/plotly (-astra) из исходников.
# Источники (фиксируются в документации):
#   owslib, nbformat: исходные пакеты Debian stretch (archive.debian.org, pool)
#   plotly:           исходный пакет Debian stretch-backports + plotly.js из sdist PyPI
# Машинная проверка хэшей — dpkg-source при распаковке (см. src/*.dsc).
set -e
M="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd $M/src

mkdeb() { # $1=stage $2=name $3=version $4=debfile
  local size
  size=$(du -sk --exclude=DEBIAN "$1" | cut -f1)
  printf 'Installed-Size: %s\n' "$size" >> "$1/DEBIAN/control"
  sudo chown -R root:root "$1"
  dpkg-deb --build "$1" "$M/$4"
  sudo chown -R "$USER:$USER" "$1"
}

# ---------------------------------------------------------------- owslib
cd $M/src/owslib-0.14.0
ST=$M/src/stage-owslib
rm -rf "$ST"; mkdir -p "$ST"
python3 setup.py -q install --root="$ST" --install-layout=deb
OWS_DEP="python3 (>= 3.4), python3-dateutil, python3-tz, python3-requests, python3-lxml, python3-pyproj"
if grep -rq 'pkg_resources' "$ST/usr/lib/python3/dist-packages/owslib"; then
  OWS_DEP="$OWS_DEP, python3-setuptools"
fi
mkdir -p "$ST/usr/share/doc/python3-owslib" "$ST/DEBIAN"
cp debian/copyright "$ST/usr/share/doc/python3-owslib/"
cat > "$ST/DEBIAN/control" <<EOF
Package: python3-owslib
Version: 0.14.0-1astra1
Section: python
Priority: optional
Architecture: all
Maintainer: Local build (Astra Linux SE 1.6)
Description: Client library for Open Geospatial (OGC) web services (Python 3)
 Сборка из исходного пакета Debian stretch (owslib 0.14.0-1, archive.debian.org).
 Заменяет ранее использовавшийся бинарный .deb оттуда же.
Должно зависеть от: $OWS_DEP
EOF
sed -i 's/^Должно зависеть от:/Depends:/' "$ST/DEBIAN/control"
mkdeb "$ST" python3-owslib 0.14.0-1astra1 python3-owslib_0.14.0-1astra1_all.deb

# ---------------------------------------------------------------- nbformat
cd $M/src/nbformat-4.2.0
ST=$M/src/stage-nbformat
rm -rf "$ST"; mkdir -p "$ST"
python3 setup.py -q install --root="$ST" --install-layout=deb
NB_DEP="python3 (>= 3.4), python3-jsonschema, python3-jupyter-core, python3-traitlets, python3-ipython-genutils"
if grep -rq 'pkg_resources' "$ST/usr/lib/python3/dist-packages/nbformat"; then
  NB_DEP="$NB_DEP, python3-setuptools"
fi
mkdir -p "$ST/usr/share/doc/python3-nbformat" "$ST/DEBIAN"
cp debian/copyright "$ST/usr/share/doc/python3-nbformat/"
cat > "$ST/DEBIAN/control" <<EOF
Package: python3-nbformat
Version: 4.2.0-1astra1
Section: python
Priority: optional
Architecture: all
Maintainer: Local build (Astra Linux SE 1.6)
Description: Jupyter notebook format (Python 3)
 Сборка из исходного пакета Debian stretch (nbformat 4.2.0-1, archive.debian.org).
Depends: $NB_DEP
EOF
mkdeb "$ST" python3-nbformat 4.2.0-1astra1 python3-nbformat_4.2.0-1astra1_all.deb

# ---------------------------------------------------------------- plotly
cd $M/src/plotly-2.1.0+dfsg
ST=$M/src/stage-plotly-new
rm -rf "$ST"; mkdir -p "$ST"
python3 setup.py -q install --root="$ST" --install-layout=deb

# plotly.js: бандл dfsg-репака вырезан — восстанавливаем из sdist PyPI plotly 2.1.0
SDIST=$M/src/plotly-2.1.0-pypi.tar.gz
if [ ! -f "$SDIST" ]; then
  URL=$(python3 -c "
import json, urllib.request
d = json.loads(urllib.request.urlopen('https://pypi.org/pypi/plotly/2.1.0/json').read().decode())
print([u['url'] for u in d['urls'] if u['packagetype'] == 'sdist'][0])")
  curl -fsSL "$URL" -o "$SDIST"
fi
JS_MEMBER=$(tar tzf "$SDIST" | grep -E '/plotly(\.min)?\.js$' | head -1)
mkdir -p "$ST/usr/share/python3-plotly"
tar xzf "$SDIST" -O "$JS_MEMBER" > "$ST/usr/share/python3-plotly/plotly.js"
mkdir -p "$ST/usr/share/doc/python3-plotly" "$ST/DEBIAN"
cp debian/copyright "$ST/usr/share/doc/python3-plotly/"
cat > "$ST/DEBIAN/control" <<'EOF'
Package: python3-plotly
Version: 2.1.0+dfsg-1~bpo9+1astra2
Section: python
Priority: optional
Architecture: all
Maintainer: Local build (Astra Linux SE 1.6)
Description: Python plotting library (Python 3)
 Сборка из исходного пакета Debian stretch-backports (plotly 2.1.0+dfsg-1~bpo9+1)
 с восстановленным из sdist PyPI бандлом plotly.js (/usr/share/python3-plotly/).
 Заменяет перепаковку бинарного .deb (…astra1).
Depends: python3 (>= 3.4), python3-six (>= 1.8.0), python3-requests (>= 2.3.0),
 python3-tz (>= 2012c), python3-decorator (>= 4.0.6), python3-nbformat (>= 4.2.0)
EOF
mkdeb "$ST" python3-plotly 2.1.0+dfsg-1~bpo9+1astra2 python3-plotly_2.1.0+dfsg-1~bpo9+1astra2_all.deb

ls -la $M/*.deb
