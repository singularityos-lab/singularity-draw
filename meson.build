project('singularity-draw', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.59.0'
)

i18n = import('i18n')
add_project_arguments('-DGETTEXT_PACKAGE="singularity-draw"', language: 'c')
add_project_arguments('-w', language: 'c')
subdir('po')

cc        = meson.get_compiler('c')
gee_dep   = dependency('gee-0.8')
gio_dep   = dependency('gio-2.0')
xml_dep   = dependency('libxml-2.0')
zlib_dep  = dependency('zlib')
cairo_dep = dependency('cairo')
pango_dep = dependency('pangocairo')
pixbuf_dep = dependency('gdk-pixbuf-2.0')
gtk_dep   = dependency('gtk4')
math_dep  = cc.find_library('m')
sqlite_dep = dependency('sqlite3')

json_dep  = dependency('json-glib-1.0')
core_deps = [gee_dep, gio_dep, xml_dep, zlib_dep, cairo_dep, pango_dep, pixbuf_dep, gtk_dep, math_dep, sqlite_dep, json_dep]

model = files(
  'src/model/geometry.vala',
  'src/model/style.vala',
  'src/model/library.vala',
  'src/model/items.vala',
  'src/model/router.vala',
  'src/model/document.vala',
  'src/model/boolean.vala',
  'src/model/layout.vala',
  'src/model/csv.vala',
  'src/model/templates.vala',
  'src/model/raster.vala',
  'src/model/stencil.vala',
  'src/model/stencils/general.vala',
  'src/model/stencils/business.vala',
  'src/model/stencils/bpmn.vala',
  'src/model/stencils/uml.vala',
  'src/model/stencils/database.vala',
  'src/model/stencils/network.vala',
  'src/model/stencils/cloud.vala',
  'src/model/stencils/electrical.vala',
  'src/model/stencils/plans.vala',
  'src/model/stencils/schedule.vala',
  'src/model/stencils/engineering.vala',
  'src/model/stencils/engineering_extra.vala',
  'src/model/stencils/business_extra.vala',
  'src/model/stencils/plans_extra.vala',
  'src/model/stencils/general_extra.vala',
  'src/model/review.vala',
  'src/model/shapesheet.vala',
  'src/model/sheet_eval.vala',
  'src/model/theme.vala',
  'src/model/datalink.vala',
  'src/model/gantt.vala',
  'src/model/validation.vala',
  'src/model/swimlanes.vala',
  'src/model/datasource_io.vala',
  'src/model/shapeops.vala',
  'src/model/reports.vala',
  'src/model/merge.vala',
  'src/model/rich_runs.vala',
  'src/model/three_way.vala',
)

paint = files(
  'src/paint/brush.vala',
  'src/paint/fill.vala',
  'src/paint/selection.vala',
)

render = files(
  'src/render/renderer.vala',
  'src/render/export.vala',
  'src/render/jumps.vala',
  'src/render/datagraphics.vala',
)

io = files(
  'src/io/zip.vala',
  'src/io/xml.vala',
  'src/io/formats.vala',
  'src/io/native.vala',
  'src/io/svg_writer.vala',
  'src/io/svg_reader.vala',
  'src/io/odg.vala',
  'src/io/vsdx.vala',
  'src/io/drawio.vala',
  'src/io/ora.vala',
  'src/io/cfb.vala',
  'src/io/vsd.vala',
  'src/io/html.vala',
  'src/io/pptx.vala',
)

core = model + render + io + paint
vector_engine_dep = declare_dependency(sources: core, dependencies: core_deps)

libsingularity_dep = dependency('singularity-1.0',
  fallback: ['libsingularity', 'libsingularity_dep']
)

if not meson.is_subproject() and libsingularity_dep.type_name() == 'internal'
  libsingularity_vapi_dir = join_paths(meson.project_build_root(), 'subprojects', 'libsingularity')
  add_project_arguments(['--vapidir=' + libsingularity_vapi_dir], language: 'vala')
endif

gnome = import('gnome')
resources = gnome.compile_resources(
  'singularity-draw-resources',
  'resources/dev.sinty.draw.gresource.xml',
  source_dir: meson.current_source_dir() / 'data' / 'icons',
)

ui = files(
  'src/ui/canvas.vala',
  'src/ui/rulers.vala',
  'src/ui/minimap.vala',
  'src/ui/library_panel.vala',
  'src/ui/inspector.vala',
  'src/ui/dialogs.vala',
  'src/ui/clipboard.vala',
  'src/ui/ribbon.vala',
  'src/ui/window.vala',
  'src/ui/app.vala',
  'src/ui/cloud_actions.vala',
  'src/ui/cloud_sync.vala',
  'src/ui/paint_controller.vala',
  'src/ui/paint_panel.vala',
  'src/ui/test_script.vala',
  'src/ui/shapesheet_panel.vala',
  'src/ui/office_ui.vala',
  'src/model/live_sync.vala',
  'src/ui/live_draw.vala',
  'src/ui/print_source.vala',
  'src/ui/rich_text.vala',
)
vector_ui_dep = declare_dependency(sources: ui + [resources], dependencies: [libsingularity_dep])
vector_canvas_dep = declare_dependency(
  sources: files('src/ui/canvas.vala', 'src/ui/paint_controller.vala') + [resources],
  dependencies: [libsingularity_dep],
)

executable('singularity-draw',
  core + ui + [resources],
  dependencies: core_deps + [libsingularity_dep],
  vala_args: ['--pkg', 'zlib'],
  install: true
)

install_data('data/dev.sinty.draw.desktop',
  install_dir: get_option('datadir') / 'applications'
)

install_data('data/dev.sinty.draw.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)

install_data('data/dev.sinty.draw.json',
  install_dir: get_option('datadir') / 'singularity' / 'app-settings'
)

install_data('data/dev.sinty.draw.open.ini',
  install_dir: get_option('datadir') / 'singularity' / 'files-actions'
)

install_data('data/dev.sinty.draw.xml',
  install_dir: get_option('datadir') / 'mime' / 'packages'
)

install_data('data/icons/dev.sinty.draw.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
)

test_env = ['TMPDIR=' + meson.current_build_dir(), 'DRAW_FIXTURES=' + meson.current_source_dir() / 'tests' / 'fixtures']

model_test = executable('draw-model-test',
  core + files('tests/model_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('model', model_test, env: test_env)

io_test = executable('draw-io-test',
  core + files('tests/io_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('io', io_test, env: test_env)

svg_test = executable('draw-svg-test',
  core + files('tests/svg_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('svg', svg_test, env: test_env)

odg_test = executable('draw-odg-test',
  core + files('tests/odg_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('odg', odg_test, env: test_env)

vsdx_test = executable('draw-vsdx-test',
  core + files('tests/vsdx_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('vsdx', vsdx_test, env: test_env)

drawio_test = executable('draw-drawio-test',
  core + files('tests/drawio_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('drawio', drawio_test, env: test_env)

paint_test = executable('draw-paint-test',
  core + files('tests/paint_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('paint', paint_test, env: test_env)

raster_io_test = executable('draw-raster-io-test',
  core + files('tests/raster_io_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('raster-io', raster_io_test, env: test_env)

stencil_test = executable('draw-stencil-test',
  core + files('tests/stencil_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('stencil', stencil_test, env: test_env, timeout: 120)

vsd_test = executable('draw-vsd-test',
  core + files('tests/vsd_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('vsd', vsd_test, env: test_env, timeout: 120)

shapesheet_test = executable('draw-shapesheet-test',
  core + files('tests/shapesheet_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('shapesheet', shapesheet_test, env: test_env, timeout: 120)

features_test = executable('draw-features-test',
  core + files('tests/features_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('features', features_test, env: test_env, timeout: 120)

office_test = executable('draw-office-test',
  core + files('tests/office_test.vala'),
  dependencies: core_deps,
  vala_args: ['--pkg', 'zlib'],
)
test('office', office_test, env: test_env, timeout: 120)

sync_test = executable('draw-sync-test',
  core + files('src/ui/cloud_sync.vala', 'tests/sync_test.vala'),
  dependencies: core_deps + [libsingularity_dep],
  vala_args: ['--pkg', 'zlib'],
)
test('sync', sync_test, env: test_env, timeout: 120)

live_test = executable('draw-live-test',
  core + files('src/model/live_sync.vala', 'tests/live_test.vala'),
  dependencies: core_deps + [libsingularity_dep],
  vala_args: ['--pkg', 'zlib'],
)
test('live', live_test, env: test_env, timeout: 120)
