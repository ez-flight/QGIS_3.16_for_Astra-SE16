#!/bin/bash
# Конфигурация QGIS 3.16.16 для Astra Linux SE 1.6 (Qt 5.11 / gcc 6.3 / Python 3.5)
set -e
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$ROOT/build"
exec "$ROOT/cmake-3.16.9-Linux-x86_64/bin/cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DWITH_3D=OFF \
  -DWITH_GRASS=OFF \
  -DWITH_SERVER=OFF \
  -DENABLE_TESTS=OFF \
  -DWITH_APIDOC=OFF \
  -DUSE_CCACHE=ON \
  "$ROOT/src/QGIS-final-3_16_16"
