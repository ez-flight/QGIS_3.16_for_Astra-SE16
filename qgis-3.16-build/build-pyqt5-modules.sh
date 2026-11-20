#!/bin/bash
# Добор недостающих python-модулей PyQt5 5.10.1 под системный Qt 5.11 Astra 1.6
# Astra поставляет python3-pyqt5 с урезанным набором модулей (без QtSql и др.),
# из-за чего PyQGIS (qgis.core) не импортируется.
set -e
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$ROOT/src/PyQt5_gpl-5.10.1"
python3 configure.py \
  --confirm-license \
  --qmake=/usr/lib/qt5/bin/qmake \
  --no-doc \
  --no-designer-plugin \
  --no-qml-plugin \
  --enable=QtSql \
  --enable=QtSvg \
  --enable=QtOpenGL \
  --enable=QtWebKit \
  --enable=QtWebKitWidgets \
  --enable=QtSerialPort \
  --enable=QtXmlPatterns
make -j4
sudo make install
