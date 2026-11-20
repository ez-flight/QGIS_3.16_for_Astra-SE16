#!/bin/bash
# Сборка 4 ядровых пакетов локального репозитория QGIS 3.16.16 для Astra SE 1.6.
# Payload — точная копия установленных на машине сборки файлов (проверенная связка).
set -e
B="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
W=$B/build
OUT=$B/debs
mkdir -p "$W" "$OUT"

control() { # $1 = staging dir
  mkdir -p "$1/DEBIAN"
}

mk() { # $1 = staging dir, $2 = deb filename
  local size
  size=$(du -sk --exclude=DEBIAN "$1" | cut -f1)
  printf 'Installed-Size: %s\n' "$size" >> "$1/DEBIAN/control"
  sudo chown -R root:root "$1"
  dpkg-deb --build "$1" "$OUT/$2"
  sudo chown -R "$USER:$USER" "$1"
}

# ---------------------------------------------------------------- 1. qgis-local
S=$W/qgis-local
rm -rf "$S"; control "$S"
mkdir -p "$S/usr/local/bin" "$S/usr/local/lib" "$S/usr/local/share/applications" \
         "$S/usr/local/share/icons" "$S/usr/local/share/metainfo"
cp -a --no-preserve=ownership /usr/local/bin/qgis /usr/local/bin/qgis_process "$S/usr/local/bin/"
cp -a --no-preserve=ownership /usr/local/lib/libqgis_analysis.so* /usr/local/lib/libqgis_app.so* \
      /usr/local/lib/libqgis_core.so* /usr/local/lib/libqgis_gui.so* \
      /usr/local/lib/libqgis_native.so* /usr/local/lib/libqgispython.so* "$S/usr/local/lib/"
cp -a --no-preserve=ownership /usr/local/lib/qgis "$S/usr/local/lib/"
cp -a --no-preserve=ownership /usr/local/share/qgis "$S/usr/local/share/"
cp -a --no-preserve=ownership /usr/local/share/applications/org.qgis.qgis.desktop "$S/usr/local/share/applications/"
cp -a --no-preserve=ownership /usr/local/share/icons/hicolor "$S/usr/local/share/icons/"
cp -a --no-preserve=ownership /usr/local/share/metainfo/org.qgis.qgis.appdata.xml "$S/usr/local/share/metainfo/"
cat > "$S/DEBIAN/control" <<'EOF'
Package: qgis-local
Version: 3.16.16-astra1
Section: science
Priority: optional
Architecture: amd64
Maintainer: Local build (Astra Linux SE 1.6)
Description: QGIS 3.16.16 LTR, сборка из исходников для Astra SE 1.6 (Qt 5.11)
 Самодостаточный настольный QGIS: бинарники, libqgis_*, провайдеры,
 python-модули PyQGIS, ядровые плагины (MetaSearch, Processing, db_manager).
Depends: libc6, libgcc1, libstdc++6, zlib1g, libpython3.5,
 libqt5core5a, libqt5gui5, libqt5widgets5, libqt5network5, libqt5xml5,
 libqt5concurrent5, libqt5printsupport5, libqt5serialport5, libqt5sql5,
 libqt5svg5, libqt5webkit5, libqt5dbus5, libqt5qml5, libqt5quick5,
 libqt5quickwidgets5, libqt5keychain1, libqca-qt5-2, libqwt-qt5-6,
 libgdal20, libproj12, libgeos-c1v5, libspatialite7, libsqlite3-0,
 libnetcdf11, libhdf5-100, libsz2, libexiv2-14, libzip4, libgsl2,
 libpq5, libexpat1, libxml2, libprotobuf-lite10,
 python3, python3-pyqt5, python3-pyqt5.qsci, python3-sip,
 libqscintilla2-qt5-local, libspatialindex-local, python3-pyqt5-modules-local,
 python3-yaml, python3-gdal, python3-psycopg2, python3-numpy, python3-jinja2,
 python3-owslib, python3-pyproj, python3-pygments, python3-plotly, python3-nbformat
EOF
mk "$S" qgis-local_3.16.16-astra1_amd64.deb

# ------------------------------------------------- 2. libqscintilla2-qt5-local
S=$W/libqscintilla2-qt5-local
rm -rf "$S"; control "$S"
mkdir -p "$S/usr/lib/x86_64-linux-gnu"
cp -a --no-preserve=ownership /usr/lib/x86_64-linux-gnu/libqscintilla2_qt5.so "$S/usr/lib/x86_64-linux-gnu/"
cp -a --no-preserve=ownership /usr/lib/x86_64-linux-gnu/libqscintilla2_qt5.so.15 "$S/usr/lib/x86_64-linux-gnu/"
cp -a --no-preserve=ownership /usr/lib/x86_64-linux-gnu/libqscintilla2_qt5.so.15.0 "$S/usr/lib/x86_64-linux-gnu/"
cp -a --no-preserve=ownership /usr/lib/x86_64-linux-gnu/libqscintilla2_qt5.so.15.0.0 "$S/usr/lib/x86_64-linux-gnu/"
cat > "$S/DEBIAN/control" <<'EOF'
Package: libqscintilla2-qt5-local
Version: 2.11.6-astra1
Section: libs
Priority: optional
Architecture: amd64
Maintainer: Local build (Astra Linux SE 1.6)
Description: QScintilla 2.11.6 (Qt5), собрана из исходников
 Runtime для qgis-local (сoname libqscintilla2_qt5.so.15).
 Не пересекается с дистрибутивной libqt5scintilla2-12v5 (soname .so.12).
Depends: libc6, libstdc++6,
 libqt5core5a, libqt5gui5, libqt5widgets5, libqt5printsupport5
EOF
mk "$S" libqscintilla2-qt5-local_2.11.6-astra1_amd64.deb

# ------------------------------------------------------ 3. libspatialindex-local
S=$W/libspatialindex-local
rm -rf "$S"; control "$S"
mkdir -p "$S/usr/local/lib"
cp -a --no-preserve=ownership /usr/local/lib/libspatialindex.so /usr/local/lib/libspatialindex.so.4 \
      /usr/local/lib/libspatialindex.so.4.1.0 /usr/local/lib/libspatialindex_c.so \
      /usr/local/lib/libspatialindex_c.so.4 /usr/local/lib/libspatialindex_c.so.4.1.0 \
      "$S/usr/local/lib/"
cat > "$S/DEBIAN/control" <<'EOF'
Package: libspatialindex-local
Version: 1.8.5-astra1
Section: libs
Priority: optional
Architecture: amd64
Maintainer: Local build (Astra Linux SE 1.6)
Description: libspatialindex 1.8.5, собрана из исходников
 Runtime для qgis-local (soname libspatialindex.so.4).
Depends: libc6, libstdc++6
EOF
mk "$S" libspatialindex-local_1.8.5-astra1_amd64.deb

# ----------------------------------------------- 4. python3-pyqt5-modules-local
S=$W/python3-pyqt5-modules-local
rm -rf "$S"; control "$S"
D="$S/usr/lib/python3/dist-packages/PyQt5"
mkdir -p "$D"
for m in QtSql QtSvg QtOpenGL QtWebKit QtWebKitWidgets QtSerialPort QtXmlPatterns; do
  cp -a --no-preserve=ownership "/usr/lib/python3/dist-packages/PyQt5/$m.so" "/usr/lib/python3/dist-packages/PyQt5/$m.pyi" "$D/"
done
cat > "$S/DEBIAN/control" <<'EOF'
Package: python3-pyqt5-modules-local
Version: 5.10.1-astra1
Section: python
Priority: optional
Architecture: amd64
Maintainer: Local build (Astra Linux SE 1.6)
Description: 7 модулей PyQt5 5.10.1, дособранных для PyQGIS
 В astra-сборке python3-pyqt5 отсутствуют QtSql/QtSvg/QtOpenGL/QtWebKit/
 QtWebKitWidgets/QtSerialPort/QtXmlPatterns — без них PyQGIS не импортируется.
 Собраны из PyQt5_gpl-5.10.1 тем же sip 4.19.8.
Depends: python3 (>= 3.5), python3-pyqt5 (>= 5.10),
 libqt5sql5, libqt5svg5, libqt5opengl5, libqt5webkit5, libqt5serialport5,
 libqt5xmlpatterns5, libgl1
EOF
mk "$S" python3-pyqt5-modules-local_5.10.1-astra1_amd64.deb

ls -la "$OUT"
