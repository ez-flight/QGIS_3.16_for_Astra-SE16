# QGIS 3.16: локальный репозиторий и массовое развёртывание

Wiki-документ (обновляемый). Связан с [QGIS-на-Astra-SE16.md](QGIS-на-Astra-SE16.md) (стратегия, сборка) — см. раздел 4А там.

- **Цель:** установка готового QGIS 3.16.16 на машины Astra Linux SE 1.6 (+ОУ10) **без компиляции** — из собственного apt-репозитория.
- **Статус (20.11.2026):** ✅ пакеты собраны — 4 ядровых .deb + 4 самосбора python (итого 8, ГОСТ-суммы в журнале раздела 8); ✅ локальный репозиторий reprepro поднят на машине разработки (`qgis-local-repo/repo/`, дымовой тест apt пройден). ⏳ Осталось: пробная установка на чистой ВМ с ОУ10, зеркалирование runtime-зависимостей с диска Astra (раздел 2.2), решение по МКЦ-исключениям (раздел 5).
- **Принцип:** сборка выполняется один раз на машине разработчика; на целевые машины попадают только готовые .deb через `apt`.

---

## 1. Архитектура

```
[Машина сборки]                    [Файл-сервер / веб]                [Целевые машины]
qgis+deps собраны в /usr/local ──▶ локальный apt-репозиторий ──▶ apt install qgis-local
        │                                  │
        ├─ сборка .deb (раздел 3)          ├─ reprepro/dpkg-scanpackages (раздел 4)
        └─ контрольные суммы               └─ GPG-подпись (опционально) / trusted=yes
```

Ключевые решения:

| Вопрос | Решение | Почему |
|---|---|---|
| Префикс установки | `/usr/local` (как собрано) | Изоляция от пакетов Astra; простой съём payload для .deb; удаление = `dpkg -r` |
| Формат распространения | собственные .deb в собственном репозитории | Штатный механизм apt, зависимости, обновления, откат (`apt install qgis-local=3.16.16-astra1`) |
| Тулчейн на целевых машинах | **не нужен** | Все `-dev` пакеты остаются только на машине сборки |
| Целевые машины в закрытом контуре | зеркалируем runtime-зависимости из репозитория Astra в локальный репозиторий | Не зависим от доступности dl.astralinux.ru с целевых сетей |
| Источники пакетов репозитория (**решение 20.11.2026**) | только (а) дистрибутивные репозитории Astra 1.6 (диск/его зеркало) и (б) **собственная сборка из зафиксированных исходников** | Бинарные .deb третьих сторон (archive.debian.org и пр.) в контур **не допускаются**; всё, чего нет на диске Astra, собирается самостоятельно — источники зафиксированы в разделе 2.4 |

---

## 2. Состав локального репозитория

Три группы пакетов:

### 2.1. Собственная сборка (ядро) — ✅ собрано 20.11.2026

| Пакет | Версия | Содержимое | Источник |
|---|---|---|---|
| `qgis-local` | 3.16.16-astra1 | `/usr/local/bin` (qgis, qgis_process), `libqgis_*.so*`, `lib/qgis/` (crssync, провайдеры), `share/qgis/` (вкл. python и ядровые плагины), desktop-файл, иконки, metainfo | сборка QGIS 3.16.16, скрипт `qgis-local-repo/build-core-debs.sh` |
| `libqscintilla2-qt5-local` | 2.11.6-astra1 | `libqscintilla2_qt5.so.15*` в `/usr/lib/x86_64-linux-gnu/` | QScintilla 2.11.6 (Qt5), собрана из исходников |
| `libspatialindex-local` | 1.8.5-astra1 | `/usr/local/lib/libspatialindex*.so.4*` | spatialindex 1.8.5, собрана из исходников |
| `python3-pyqt5-modules-local` | 5.10.1-astra1 | 7 модулей PyQt5 (`QtSql QtSvg QtOpenGL QtWebKit QtWebKitWidgets QtSerialPort QtXmlPatterns`, `.so`+`.pyi`) в `/usr/lib/python3/dist-packages/PyQt5/` | `PyQt5_gpl-5.10.1`, тем же sip 4.19.8 |
| `python3-pyproj` | 1.9.6-1astra1 | pyproj против системного `libproj12` | upstream 1.9.6 (см. раздел 2.4) |
| `python3-owslib` | 0.14.0-**1astra1** | `owslib` в dist-packages | **самосбор** из исходного пакета Debian stretch (заменяет бинарный .deb archive.debian.org — см. 2.4) |
| `python3-nbformat` | 4.2.0-**1astra1** | `nbformat` в dist-packages (+ `/usr/bin/jupyter-trust`) | **самосбор** из исходного пакета Debian stretch |
| `python3-plotly` | 2.1.0+dfsg-**1~bpo9+1astra2** | `plotly` в dist-packages + `/usr/share/python3-plotly/plotly.js` | **самосбор** из исходного пакета Debian stretch-backports + plotly.js из sdist PyPI |

Скрипт самосборов python-пакетов: `metasearch-deb/build-python-debs.sh` (staged install + `dpkg-deb`, контрольные суммы исходников проверяются `dpkg-source` по `.dsc`).

Исключён из своих пакетов: **`python3-pygments`** — оказался **на диске Astra** (`repository-dev`/`repository-dev-update`, 2.2.0+dfsg-1(+deb9u2)): на целевые машины поставляется как обычная дистрибутивная зависимость (раздел 2.2), самосбор не требуется.

Пересечений с пакетами Astra по файлам нет: QScintilla-самосбор имеет soname `libqscintilla2_qt5.so.15`, дистрибутивная Qt5-QScintilla 2.9.3 — `libqt5scintilla2.so.12` (пакет `libqt5scintilla2-12v5`); PyQt5-модули в astra-сборке `python3-pyqt5` отсутствуют (пути свободны); `/usr/local/*` пакетами Astra не занят.

### 2.2. Runtime-зависимости (из репозитория Astra)

Полный список — после сборки, по `ldd` бинарников (чек-лист раздела 7). Гарантированно нужны:

- **Qt 5.11 runtime:** `libqt5core5a libqt5gui5 libqt5widgets5 libqt5network5 libqt5xml5 libqt5svg5 libqt5sql5 libqt5sql5-sqlite libqt5printsupport5 libqt5opengl5 libqt5xmlpatterns5 libqt5serialport5 libqt5webkit5` (+ пакет с `libQt5UiTools`, уточнить: `libqt5designer5`?)
- **Крипто/ключи:** `libqca-qt5-2 libqca-qt5-2-plugins libqt5keychain1`
- **Гео-стек:** `libgdal20 libproj12 libgeos-c1v5` (имя пакета GEOS 3.9 — уточнить) `libspatialite7 libsqlite3-0`
- **Python:** `python3 python3-pyqt5 python3-pyqt5.qsci python3-sip` (+ `python3-pyqt5.qtwebkit` — если есть в репозитории и нужен плагинам)
- **Python для плагинов (MetaSearch + Processing + графики):** `python3-yaml python3-gdal python3-psycopg2 python3-numpy python3-requests python3-dateutil python3-six python3-tz python3-lxml python3-jinja2 python3-decorator python3-traitlets python3-jsonschema python3-jupyter-core python3-ipython-genutils` + собственные `python3-owslib`, `python3-pygments`, `python3-pyproj`, `python3-plotly`, `python3-nbformat` (раздел 2.1) — иначе на целевых машинах **все ядровые плагины** (MetaSearch, Processing, db_manager) падают с CRITICAL при каждом запуске. `python3-gdal` — строго той же версии, что системный GDAL (2.1.2)
- **Прочее:** `libprotobuf-lite10 libqwt-qt5-6 libgsl2 libexiv2-14 libzip4 libpq5 libexpat1 libxml2 zlib1g libgl1 libqt5keychain1 libqca-qt5-2`

Все перечисленные пакеты присутствуют в дистрибутивных репозиториях Astra 1.6 (проверено `apt-cache policy` 20.11.2026): базовые — в `repository`/`repository-update`, Qt-dev и часть runtime — в `repository-dev`/`repository-dev-update`. Для закрытого контура зеркалируются оттуда же (с диска/зеркала диска) — включить в локальный репозиторий тем же `reprepro includedeb`.

### 2.4. Пакеты, отсутствующие на диске Astra: источники самосбора (зафиксировано)

В репозиторий попадают только самосборы; исходники для воспроизводимости хранятся в `metasearch-deb/src/` (python) и `qgis-3.16-build/tarballs/` (C++-стек).

| Пакет (сборка) | Исходник | Где взят (20.11.2026) | Контроль |
|---|---|---|---|
| `python3-owslib` 0.14.0-1astra1 | `owslib_0.14.0-1.dsc` + `owslib_0.14.0.orig.tar.gz` + `owslib_0.14.0-1.debian.tar.xz` | `http://archive.debian.org/debian/pool/main/o/owslib/` | хэши проверяет `dpkg-source` при распаковке |
| `python3-nbformat` 4.2.0-1astra1 | `nbformat_4.2.0-1.dsc` + `nbformat_4.2.0.orig.tar.gz` + `nbformat_4.2.0-1.debian.tar.xz` | `http://archive.debian.org/debian/pool/main/n/nbformat/` | хэши `.dsc` |
| `python3-plotly` …astra2 | `plotly_2.1.0+dfsg-1~bpo9+1.dsc` + `plotly_2.1.0+dfsg.orig.tar.gz` + `plotly_2.1.0+dfsg-1~bpo9+1.debian.tar.xz`; plotly.js — из `plotly-2.1.0` **sdist PyPI** (`plotly-2.1.0-pypi.tar.gz`, сохранён в `src/`) | `http://archive.debian.org/debian/pool/main/p/plotly/`, `https://pypi.org/project/plotly/2.1.0/` | хэши `.dsc`; бандл из скачанного sdist |
| `python3-pyproj` 1.9.6-1astra1 | `pyproj_1.9.6.orig.tar.gz` (upstream release) | PyPI / upstream (`metasearch-deb/src/`) | зафиксирован в `src/` |
| `qgis-local` | QGIS `final-3_16_16` + патч `ogrAttId` (см. `qgis-3.16-build/README.md`) | `https://github.com/qgis/QGIS` | тарболл в `tarballs/` |
| `libqscintilla2-qt5-local` | `QScintilla-2.11.6.tar.gz` | Riverbank Computing | в `tarballs/` |
| `libspatialindex-local` | `spatialindex-src-1.8.5.tar.gz` | `github.com/libspatialindex/libspatialindex` | в `tarballs/` |
| `python3-pyqt5-modules-local` | `PyQt5_gpl-5.10.1.tar.gz` | Riverbank Computing (SourceForge) | в `tarballs/` |

Дополнительно (не пакет, а файл данных): sip-файлы QScintilla — `qgis-3.16-build/qscintilla-sip/Qsci/`. Бывшие бинарные .deb из archive.debian.org (owslib, pygments, nbformat) и перепаковка plotly …astra1 отложены в `metasearch-deb/superseded/` — в контур не идут (решение раздела 1).

### 2.3. Служебное

- `README`/инструкция по подключению репозитория (для админов целевых машин);
- файлы контрольных сумм (ГОСТ, `gostsum -d`) всех .deb — по конвенции проекта;
- (опционально) GPG-ключ подписи репозитория.

---

## 3. Сборка .deb из результата компиляции

### 3.1. qgis-local

✅ **Выполнено 20.11.2026** — скриптом `qgis-local-repo/build-core-debs.sh` (payload — точная копия проверенной установки `cp -a`, staging `chown root:root`, `dpkg-deb --build`; МКЦ `astra-nochmodx-lock` выключался на время сборки и возвращался — обязательный протокол).

Фактический control собранного `qgis-local_3.16.16-astra1_amd64.deb` (Depends — прямой список из `readelf -d` всех бинарников/библиотек/плагинов, сопоставление `dpkg -S`; транзитивное apt добирает сам):

```
Package: qgis-local
Version: 3.16.16-astra1
Section: science
Priority: optional
Architecture: amd64
Maintainer: Local build (Astra Linux SE 1.6)
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
```

- В пакете 3391 файл (~57 МБ): бинарники, 6 libqgis, провайдеры, `share/qgis` (включая python и ядровые плагины), desktop-файл, иконки, metainfo. Headers (`/usr/local/include`) не включены — runtime-пакет.
- Отличия от ранее планировавшегося списка (по факту прямых NEEDED): добавлены `libqt5dbus5 libqt5qml5 libqt5quick5 libqt5quickwidgets5` (Qt-стек gui/webkit), `libnetcdf11 libhdf5-100 libsz2` (прямые ссылки core), `libpython3.5`, `libxml2`; GEOS-рантайм — `libgeos-c1v5`; python-стек плагинов в Depends, чтобы ядровые плагины не падали на целевых машинах сразу после установки.
- `postinst` не нужен (`ldconfig` вызывается триггером dpkg; `/usr/local/lib` входит в `ld.so.conf.d`).
- Версию пакета бампать при каждой пересборке: `-astra1`, `-astra2`…

### 3.2. libqscintilla2-qt5-local и libspatialindex-local

✅ **Выполнено 20.11.2026** (`qgis-local-repo/build-core-debs.sh`): оба пакета собраны как **runtime-only** (без headers), версии `2.11.6-astra1` и `1.8.5-astra1`. QScintilla оставлена в `/usr/lib/x86_64-linux-gnu` — soname-самосбор `.so.15` не пересекается с дистрибутивной `libqt5scintilla2.so.12` (2.9.3), конфликта файлов нет; перенос в `/usr/local` не потребовался.

### 3.3. Контроль качества пакетов

✅ **Выполнено 20.11.2026:**

```bash
dpkg-deb -f qgis-local_3.16.16-astra1_amd64.deb Package Version Depends   # метаданные
dpkg-deb --contents qgis-local_3.16.16-astra1_amd64.deb | wc -l           # 3391 файл
gostsum -d qgis-local_3.16.16-astra1_amd64.deb                            # сумма в журнале (раздел 8)
```

Самосборы python-пакетов дополнительно прошли **живую проверку на машине разработки**: установка поверх прежних версий (`dpkg -i`), импорт ядровых плагинов (`MetaSearch, db_manager, processing` — OK), импорт `owslib.wfs`/`nbformat`, генерация plotly-HTML. Тест на чистой ВМ с ОУ10 — перед публикацией на файловый сервер (чек-лист раздела 7).

---

## 4. Организация apt-репозитория

### Вариант A: reprepro (рекомендуется) ✅ выполнено 20.11.2026

Репозиторий создан на машине разработки: `qgis-local-repo/repo/` (`conf/distributions`: Codename `smolensk-local`, Suite `stable`, Components `main`, Architectures `amd64`, без подписи — на клиентах `trusted=yes`). Включены все 8 собственных пакетов раздела 2.1; `reprepro -b qgis-local-repo/repo list smolensk-local` показывает их корректно, дымовой тест `apt-get update` изолированным списком источников пройден (кандидат `qgis-local 3.16.16-astra1` виден).

Добавление новых пакетов (фактические пути машины разработки):

```bash
reprepro -b qgis-astra/qgis-local-repo/repo includedeb smolensk-local <файл>.deb
# зеркалирование runtime-зависимостей Astra (закрытый контур):
# apt download <пакеты из раздела 2.2> из репозиториев Astra
# (только диск/зеркало диска) и тем же includedeb добавить в репозиторий
```

Конфигурация репозитория — `qgis-local-repo/repo/conf/distributions` (Codename `smolensk-local`, Suite `stable`, Components `main`, Architectures `amd64`, Origin `LocalQGIS`; поле `SignWith` добавить при появлении GPG-ключа).

Раздача: любым статическим веб-сервером (nginx/apache на файловом сервере) или `python3 -m http.server` для лабораторной сети. На целевой машине:

```
deb [trusted=yes] http://file-server/repo smolensk-local main
```

(`trusted=yes` — для внутреннего контура без GPG; с GPG — подключить ключ через `signed-by`.)

### Вариант B: dpkg-scanpackages (минимум)

```bash
mkdir -p /srv/repo && cp *.deb /srv/repo/
cd /srv/repo && dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
```

На целевой машине: `deb [trusted=yes] file:/srv/repo /` (или через веб). Подходит для старта; версионирование и удаление пакетов — вручную.

---

## 5. Установка на целевую машину

Предусловия: Astra SE 1.6 + ОУ10, доступ к локальному репозиторию (сеть или съёмный носитель).

```bash
# 1. Подключить репозиторий (/etc/apt/sources.list.d/local-qgis.list)
echo 'deb [trusted=yes] http://file-server/repo smolensk-local main' | sudo tee /etc/apt/sources.list.d/local-qgis.list
# закрытый контур: добавить в репозиторий и runtime-зависимости Astra (раздел 2.2)

# 2. МКЦ: временно снять запрет бита исполнения (dpkg выставляет права)
sudo /usr/sbin/astra-nochmodx-lock disable

# 3. Установка
sudo apt update
sudo apt install qgis-local          # тянет Depends автоматически

# 4. Вернуть запрет
sudo /usr/sbin/astra-nochmodx-lock enable

# 5. Проверка
qgis --version
python3 -c "from qgis.core import QgsApplication; print('PyQGIS OK')"
```

Дополнительно:

- **Закрепление версии:** `sudo apt-mark hold qgis-local libqscintilla2-qt5-local libspatialindex-local` — чтобы случайное обновление не меняло связку без решения администратора.
- **Целостность МКЦ:** файлы собственной сборки не входят в gostsums пакетов Astra — штатная проверка целостности (fly-admin-int-check) будет считать их неучтёнными. ⚠️ Согласовать с требованиями ПОМ комплекса: либо внести `/usr/local/*` в перечень исключений, либо оформить учёт собственного пакета в процедурах.
- Установку выполнять от администратора с высоким уровнем целостности; после — контроль по процедурам объекта.

---

## 6. Обновление версий (рабочий цикл wiki)

| Событие | Действие |
|---|---|
| Новый патч-релиз QGIS 3.16.x | пересборка на машине разработки → новый `qgis-local_3.16.x-astraN` → `reprepro includedeb` → `apt update && apt install --only-upgrade qgis-local` на целевых |
| Пересборка кастомной либы | аналогично, бамп `-astraN` |
| Новые зависимости после обновления | дополнить Depends, добавить новые .deb в репозиторий |
| Откат | `apt install qgis-local=<предыдущая версия>` (reprepro хранит старые версии, пока не удалены) |
| Снятие QGIS | `sudo apt remove qgis-local libqscintilla2-qt5-local libspatialindex-local` + чистка `/usr/local/share/qgis` при необходимости |

---

## 7. Чек-лист «заполнить после завершения сборки»

Статус на 20.11.2026 (сборка и установка завершены, см. журнал [QGIS-на-Astra-SE16.md](QGIS-на-Astra-SE16.md)):

- [x] `ldd` по `libqgis_core/gui/analysis`, `qgis`, `qgis_process` выполнен — замыкание библиотек подтверждено; **прямой `Depends` сформирован и вставлен в пример control (раздел 3.1)**; транзитивные зависимости (ffmpeg-стек, odbc, kml и пр.) apt добирает сам.
- [x] `libQt5UiTools.so.5` в `ldd` **не присутствует** — рантайм-зависимость не требуется (только сборка).
- [x] python-модули: фактический импорт PyQGIS проверен (`qgis.core`, `qgis.gui` — OK); выявлен дефицит модулей PyQt5 в astra-сборке → **собраны и установлены 7 модулей** (QtSql/QtSvg/QtOpenGL/QtWebKit/QtWebKitWidgets/QtSerialPort/QtXmlPatterns); для развёртывания упаковать в `python3-pyqt5-modules-local`.
- [x] GEOS: рантайм-пакеты `libgeos-c1v5` + `libgeos-3.9.0` (в Depends включён первый).
- [x] Собраны 4 ядровых .deb (скрипт `qgis-local-repo/build-core-debs.sh`): `qgis-local 3.16.16-astra1` (3391 файл), `libqscintilla2-qt5-local 2.11.6-astra1`, `libspatialindex-local 1.8.5-astra1`, `python3-pyqt5-modules-local 5.10.1-astra1` — в `qgis-local-repo/debs/`.
- [x] Принято решение об источниках (раздел 1): **только диск Astra + собственная сборка**; owslib/nbformat/plotly **пересобраны из исходников** (-astra, скрипт `metasearch-deb/build-python-debs.sh`), `python3-pygments` исключён из своих пакетов (есть на диске Astra), сторонние бинарные .deb отложены в `metasearch-deb/superseded/`. Живая проверка самосборов на машине разработки пройдена (плагины, owslib/nbformat, plotly-HTML).
- [x] Поднят reprepro: `qgis-local-repo/repo/` (8 пакетов), дымовой тест apt пройден; ГОСТ-суммы всех 8 пакетов — в журнале ниже.
- [ ] Зеркалирование runtime-зависимостей Astra (раздел 2.2) в локальный репозиторий — для закрытого контура.
- [ ] Тестовая установка на чистой ВМ с ОУ10 (по разделу 5) до публикации на файловый сервер.
- [ ] Решение по МКЦ-исключениям `/usr/local` (раздел 5).
- [ ] Публикация репозитория на файловый сервер + инструкция для админов (2.3).

---

## 8. Журнал

### 2026-11-19
- 📐 Создана методика (настоящий документ) вперёд завершения сборки: состав репозитория, сборка .deb из `/usr/local`, reprepro + dpkg-scanpackages, порядок установки на целевые машины, МКЦ-нюансы, цикл обновлений.
- ⏳ Ожидается завершение `make -j2` на машине сборки; далее — чек-лист раздела 7.

### 2026-11-20
- ✅ Сборка завершена, QGIS 3.16.16 установлен в `/usr/local`, все тесты пройдены (см. журнал [QGIS-на-Astra-SE16.md](QGIS-на-Astra-SE16.md)).
- ✅ Фактические зависимости собраны (`ldd` + `dpkg -S`); прямой `Depends` для `qgis-local` вписан в пример control (раздел 3.1).
- ⚠️ Выявлено при тестировании: astra-сборка `python3-pyqt5` лишена модулей QtSql/QtSvg/QtWebKit/QtOpenGL/QtSerialPort/QtXmlPatterns → PyQGIS не работал; модули собраны из `PyQt5_gpl-5.10.1` и установлены вручную. **В состав репозитория добавлен четвёртый пакет `python3-pyqt5-modules-local`** (иначе целевые машины получат QGIS без работающего Python).
- ✅ Запрет бита исполнения МКЦ возвращён (АКТИВНО).
- ⚠️ **Выявлено при ручном тестировании GUI:** падают **все три** ядровых плагина (MetaSearch, Processing, db_manager; CRITICAL, виден первый по порядку) — в системе отсутствовали `owslib`/`pygments`/`jinja2`/`yaml`/`osgeo`/`psycopg2`/`numpy` (+`pyproj` как dep owslib). Замкнуто на машине разработки (пакеты в `metasearch-deb/`, ГОСТ-суммы в [qgis-3.16-build/README.md](qgis-3.16-build/README.md)): **в состав репозитория добавлены `python3-pyproj` (собственная сборка), `python3-owslib`, `python3-pygments`, `python3-plotly` (перепаковка с встроенным plotly.js), `python3-nbformat`** (раздел 2.1) + пятнадцать пакетов из репозитория Astra в Depends (раздел 2.2). Импорт всех плагинов проверен скриптом, plotly проверен генерацией HTML. Известное косметическое WARNING (osgeo → `import imp`) задокументировано — не ошибка.
- ⏳ Далее по чек-листу раздела 7: сборка четырёх .deb, reprepro, пробная ВМ.
- ✅ **Пакетирование завершено (20.11.2026).** Собраны и включены в репозиторий 8 пакетов:

| Пакет | Версия | gostsum -d (20.11.2026) |
|---|---|---|
| qgis-local | 3.16.16-astra1 | `b170ffe651cbebe5adcf7a488218510e9b9c63e989a0fa2ba32d2b50c7b724de` |
| libqscintilla2-qt5-local | 2.11.6-astra1 | `003a3b3a7187681d5651fbc4ddaae87c67e446e8f35addb8476722d0e2fcb765` |
| libspatialindex-local | 1.8.5-astra1 | `7734a3837f8451935af4f7ba14804658b878688353842171f62be73315b35578` |
| python3-pyqt5-modules-local | 5.10.1-astra1 | `cf01581b778e306e8fc6fcdf61d9baac512a1473b799f33840794d6afdf7a8a1` |
| python3-owslib (самосбор) | 0.14.0-1astra1 | `aee92f1611b3c6dba9a9183c8d85b1c44003a2f15c430034d5bddc640907f737` |
| python3-nbformat (самосбор) | 4.2.0-1astra1 | `737dc8e1d0a168b1f6ad817819a39ebd471d794a2d804e64e27e7df995c8f49f` |
| python3-plotly (самосбор) | 2.1.0+dfsg-1~bpo9+1astra2 | `990291c5941790960ac3076be14ef877747987401ffbc9db4b2faf2496bb5490` |
| python3-pyproj (самосбор) | 1.9.6-1astra1 | `9dd999c67c3ad4b9f5d0fe4585149541b0ba3d2741137b64ca56bffcc6d811ac` |

- 📌 **Решение по источникам (по указанию пользователя):** в репозиторий — только пакеты с диска Astra и собственные сборки. Пересобраны из исходников: `python3-owslib`, `python3-nbformat` (исходники Debian stretch), `python3-plotly` (исходник Debian stretch-backports + plotly.js из PyPI-sdist) — вместо ранее скачанных бинарных .deb. `python3-pygments` **не пересобран — взят с диска Astra** (repository-dev/-update). Источники всех исходников зафиксированы в разделе 2.4. Старые сторонние .deb — `metasearch-deb/superseded/`.
- 🔧 Скрипты воспроизводимой сборки: `qgis-local-repo/build-core-debs.sh` (4 ядровых), `metasearch-deb/build-python-debs.sh` (3 python-самосбора). МКЦ-протокол: `astra-nochmodx-lock disable` на время сборки/установки, `enable` после — выполнен, статус АКТИВНО.
- ⏳ Осталось: зеркало runtime-зависимостей (2.2), пробная ВМ с ОУ10, МКЦ-исключения, публикация на файловый сервер.
