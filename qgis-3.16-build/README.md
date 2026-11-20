# Сборка QGIS 3.16.16 на Astra Linux SE 1.6

**Статус: ✅ собрано, установлено, протестировано (20.11.2026).** Всё подготовлено 19–20.11.2026: зависимости установлены, cmake-конфигурация выполнена (`configure-qgis.sh`), сборка прошла 100% (патч `ogrAttId`), дособраны модули PyQt5 (`build-pyqt5-modules.sh`).

> ⚠️ 20.11.2026 каталог переехал в `qgis-astra/` — cmake-переконфигурация выполнена, кэж ссылается на новые пути. **Следующий `make` будет почти полной пересборкой** (файлы зависимостей содержат прежние абсолютные пути; ccache ускорит, но закладывайте часы).

## 1. Компиляция (выполняет пользователь)

```bash
cd qgis-astra/qgis-3.16-build/build && make -j2
```

- `-j2` — безопасно для 2,9 ГБ ОЗУ (swap 4 ГБ подстрахует). `-j4` быстрее, но со свопом.
- Ожидаемое время: 3–5 часов. Включён ccache — повторные сборки быстрее.
- Лог: `make -j2 2>&1 | tee /tmp/qgis-make.log`

## 2. Установка

```bash
sudo make install && sudo ldconfig
```

Префикс `/usr/local`: бинарники — `/usr/local/bin`, библиотеки — `/usr/local/lib`.

## 3. Проверка

```bash
qgis --version
python3 -c "from qgis.core import QgsApplication; print('PyQGIS OK')"
```

## Важно: запрет бита исполнения (МКЦ)

`astra-nochmodx-lock` сейчас **выключен** (иначе компиляция и dpkg не работают).
**После** успешной установки QGIS вернуть:

```bash
sudo /usr/sbin/astra-nochmodx-lock enable
```

## Патчи исходника

- `src/core/providers/ogr/qgsogrprovider.cpp` (~стр. 1738): опечатка `ogrAttId` → `ogrAttributeId` в ветке `#else` (компиляция с GDAL < 2.2). Без правки сборка падает с «'ogrAttId' was not declared in this scope».

## Чем собирали

| Компонент | Версия | Источник |
|---|---|---|
| cmake | 3.16.9 (бинарный Kitware) | `cmake-3.16.9-Linux-x86_64/` |
| libspatialindex | 1.8.5 | собран в `/usr/local` (тесты отключены: код тестов несовместим с gcc 6.3) |
| QScintilla | 2.11.6 (Qt5) | собрана, установлена в системные пути Qt (`/usr/lib/x86_64-linux-gnu`, headers в `/usr/include/x86_64-linux-gnu/qt5/Qsci`) |
| Qt | 5.11.0 | репозиторий Astra (dev) |
| GDAL / GEOS / PROJ / SQLite | 2.1.2 / 3.9.0 / 4.9.3 / 3.36 | репозиторий Astra |
| Python / PyQt5 / SIP | 3.5.3 / 5.10.1 / 4.19.8 | системные |
| protobuf | 3.0.0 | репозиторий Astra (обязателен для MVT) |

Отключено: 3D (нет qt3d), GRASS, Server, тесты, API-документация.
Не найдено (не критично): OpenCL, Qt5Positioning (нет dev-пакета — GPS-функции отключены).

## Исправление 20.11.2026: Python-консоль QGIS (QgsCodeEditorPython)

**Симптом**: при запуске QGIS две ошибки — `ImportError: cannot import name 'QgsCodeEditorPython'`
в `console_sci.py` и следом `NameError: name 'console' is not defined` в `console.init_options_widget()`.

**Причина**: при первичной конфигурации CMake не нашёл Qsci sip-файлы (`QSCI_SIP_DIR-NOTFOUND`) и отключил
sip-фичу `HAVE_QSCI_SIP` — классы кодового редактора не попали в модуль `qgis.gui`, из-за чего
Python-консоль падала при старте.

**Исправление**:
1. Sip-файлы QScintilla 2.11.6 скопированы в `qscintilla-sip/Qsci/` (источник: `src/QScintilla-2.11.6/Python/sip/`).
2. Переконфигурация: `cmake -DQSCI_SIP_DIR=qgis-astra/qgis-3.16-build/qscintilla-sip .` в `build/` (или повторный запуск `configure-qgis.sh` с добавленным `-DQSCI_SIP_DIR=...`).
3. Пересборка биндингов: `make -j2 && sudo make install && sudo ldconfig`.

**Важно**: перед `make` выключить `astra-nochmodx-lock` (cmake не может выставить бит исполнения
при копировании плагинов — `file COPY cannot set permissions`), после установки вернуть `enable`.
Проверено: `from qgis.gui import QgsCodeEditorPython` работает, запуск QGIS без ошибок.

## Исправление 20.11.2026: модули MetaSearch и Processing (CRITICAL при загрузке)

**Симптом:** при запуске QGIS диалоги «Ошибка загрузки модуля» — ядровые плагины не
загружаются (CRITICAL в журнале). Падали **все три** ядровых плагина; на экране виден
первый по порядку, остальные вскрываются по мере исправления.

**Причина:** сборка QGIS не тянет Python-зависимости плагинов автоматически. Стек
установленного Python 3.5 был пуст — не хватало всего.

**Полная карта зависимостей ядровых плагинов (проверено импортом каждого плагина):**

| Плагин | Нужные модули | Комментарий |
|---|---|---|
| MetaSearch | `owslib`, `pygments`, `jinja2` (+ цепочка `owslib` → `pyproj`) | `owslib/ows.py` импортирует `crs` на уровне модуля — без pyproj owslib не грузится вообще |
| Processing | `yaml`, `osgeo` (python3-gdal), `psycopg2`, `numpy` | osgeo нужен провайдеру GDAL-алгоритмов при старте |
| db_manager | — (достаточно `psycopg2` выше) | чистый Python + PyQt |
| Processing: 3 алгоритма графиков | `plotly` (BoxPlot, RasterLayerHistogram, PolarPlot) | ленивый импорт; без него три алгоритма недоступны, остальное работает |

**Замыкание (выполнено, пакеты в `~/Project/metasearch-deb/`):**

| Пакет | Откуда | Примечание |
|---|---|---|
| `python3-owslib 0.14.0-1astra1` | **самосбор** из исходного пакета Debian stretch (`archive.debian.org/pool/main/o/owslib/`, см. раздел 2.4 QGIS-массовое-развертывание.md) | эпоха python3.5 |
| `python3-pygments 2.2.0+dfsg-1` | **с диска Astra** (`repository-dev`/`repository-dev-update`) | сторонний .deb с archive.debian.org отложен в `superseded/` |
| `python3-pyproj 1.9.6-1astra1` | **собран самим** из upstream `pyproj_1.9.6.orig.tar.gz` | см. ниже |
| `python3-plotly 2.1.0+dfsg-1~bpo9+1astra2` | **самосбор** из исходного пакета Debian stretch-backports + **plotly.js из sdist PyPI** (`plotly-2.1.0`, сохранён в `src/`) | dfsg-репак вырезал бандл; патч читает `/usr/share/python3-plotly/plotly.js` |
| `python3-nbformat 4.2.0-1astra1` | **самосбор** из исходного пакета Debian stretch (`archive.debian.org/pool/main/n/nbformat/`) | зависимость plotly |
| `python3-yaml 3.12`, `python3-gdal 2.1.2`, `python3-psycopg2 2.6.2`, `python3-numpy 1.12.1`, `python3-requests`, `python3-dateutil`, `python3-six`, `python3-tz`, `python3-lxml`, `python3-jinja2`, `python3-decorator`, `python3-traitlets`, `python3-jsonschema`, `python3-jupyter-core`, `python3-ipython-genutils` | репозиторий Astra | python3-gdal строго той же версии, что системный GDAL (2.1.2) |

**Почему pyproj собирали сами:** готового `python3-pyproj` под связку Python 3.5 + `libproj12`
(PROJ 4.9.3) не существует — jessie-сборки линкованы против `libproj9`, buster+ — против
`libproj13` и требуют Python ≥ 3.6. Сборка: `PROJ_DIR=/usr python3 setup.py …` (линкуется с
системным `libproj12`, datadir → `/usr/share/proj`), упакован через staged install + `dpkg-deb`.
Исходник и stage — `metasearch-deb/src/pyproj-1.9.6rel/`. Для сборки нужны `python3-setuptools`,
`cython3` (из репозитория Astra).

Контрольные суммы (ГОСТ, `gostsum -d`, 20.11.2026) — актуальные самосборы:

| Файл | Сумма |
|---|---|
| python3-owslib_0.14.0-1astra1_all.deb | `aee92f1611b3c6dba9a9183c8d85b1c44003a2f15c430034d5bddc640907f737` |
| python3-nbformat_4.2.0-1astra1_all.deb | `737dc8e1d0a168b1f6ad817819a39ebd471d794a2d804e64e27e7df995c8f49f` |
| python3-plotly_2.1.0+dfsg-1~bpo9+1astra2_all.deb | `990291c5941790960ac3076be14ef877747987401ffbc9db4b2faf2496bb5490` |
| python3-pyproj_1.9.6-1astra1_amd64.deb | `9dd999c67c3ad4b9f5d0fe4585149541b0ba3d2741137b64ca56bffcc6d811ac` |

`python3-pygments` — из репозиториев Astra (диск), самосбор не требуется. Сторонние бинарные .deb (owslib/pygments/nbformat с archive.debian.org, перепаковка plotly …astra1) отложены в `metasearch-deb/superseded/` — в контур не идут. Скрипт воспроизводимой сборки самосборов: `metasearch-deb/build-python-debs.sh`; ядровые пакеты QGIS — `qgis-local-repo/` (см. [QGIS-массовое-развертывание.md](../QGIS-массовое-развертывание.md)).

Установка одной транзакцией (добор зависимостей из Astra):
```bash
cd metasearch-deb && sudo apt install ./python3-owslib_0.14.0-1astra1_all.deb \
  ./python3-nbformat_4.2.0-1astra1_all.deb ./python3-plotly_2.1.0+dfsg-1~bpo9+1astra2_all.deb \
  ./python3-pyproj_1.9.6-1astra1_amd64.deb \
  python3-pygments python3-yaml python3-gdal python3-psycopg2 python3-numpy \
  python3-requests python3-dateutil python3-six python3-tz python3-lxml python3-jinja2 \
  python3-decorator python3-traitlets python3-jsonschema python3-jupyter-core python3-ipython-genutils
```
Проверка (импорт всех трёх плагинов должен пройти без ошибок):
```bash
PYTHONPATH=/usr/local/share/qgis/python:/usr/local/share/qgis/python/plugins \
python3 -c "import MetaSearch, db_manager, processing; print('все ядровые плагины OK')"
python3 -c "import plotly.graph_objs, plotly.offline; \
plotly.offline.plot({'data':[plotly.graph_objs.Box(y=[1,2,3])]}, \
filename='/tmp/t.html', auto_open=False); print('plotly OK')"
```

**Известное косметическое предупреждение** (не ошибка): при загрузке плагинов в журнале QGIS раз
за запуск появляется `PendingDeprecationWarning: the imp module is deprecated` с трейсом
через `osgeo/__init__.py`. Источник — `python3-gdal 2.1.2` (SWIG-генерация делает `import imp`),
ловушка предупреждений QGIS оформляет его как WARNING. На работу не влияет; чинить нечего
(патчить файлы пакета Astra недопустимо, затихнет само при обновлении GDAL).
