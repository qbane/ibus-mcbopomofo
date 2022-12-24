project(
  'ibus-mcbopomofo', 'vala',
  version: '0.0.1')

engine_name = 'ibus-engine-mcbopomofo'

gettext_domain = 'ibus-mcbopomofo'
prefix = get_option('prefix')
bindir = prefix / get_option('bindir')
datadir = prefix / get_option('datadir')
pkgdatadir = datadir / meson.project_name().to_lower()
libexecdir = prefix / get_option('libexecdir')
localedir = prefix / get_option('localedir')

configurations = configuration_data({
  'ENGINE_NAME': engine_name,
  'PACKAGE_DATADIR': pkgdatadir,
  'PACKAGE_NAME': meson.project_name().to_lower(),
  'PACKAGE_VERSION': meson.project_version(),
  'BINDIR': bindir,
  'DATADIR': datadir,
  'PKGDATADIR': pkgdatadir,
  'LIBEXECDIR': libexecdir,
  'GETTEXT_PACKAGE': gettext_domain,
  'LOCALEDIR': localedir,
})

add_project_arguments(['-DGETTEXT_PACKAGE="@0@"'.format(gettext_domain)], language: 'c')

library_path_base = get_option('mcbopomofo_path')
if library_path_base == ''
  library_path_base = join_paths(meson.source_root(), 'mcbopomofo-core/build')
endif

cc = meson.get_compiler('c')
valac = meson.get_compiler('vala')

dependencies = [
  valac.find_library('posix'),
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('ibus-1.0', required: false),
  cc.find_library('m', required: false),
  cc.find_library('stdc++'),
  cc.find_library('McBopomofoCore',
    dirs: [
      library_path_base / 'src'
    ]),
]

subdir('data')
subdir('po')
subdir('src')

summary({
    'prefix': prefix,
    'datadir': datadir,
    'pkgdatadir': pkgdatadir,
    'libexecdir': libexecdir,
    'localedir': localedir,
    'McBopomofoCore path base': library_path_base,
  },
  section: 'Directories')

summary({
    'Engine name': engine_name,
    'Debug': get_option('debug'),
    'Optimization': get_option('optimization'),
  },
  section: 'Build',
  bool_yn: true)
