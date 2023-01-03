configure_file(
  input: 'config.h.in',
  output: 'config.h',
  configuration: configurations)

sources = files(
  'main.vala',
  'engine.vala',
  'bus_watcher.vala',
  'prop_manager.vala')

vapi_dir = meson.current_source_dir()
add_project_arguments([
  '--vapidir', vapi_dir,
  '--pkg', 'config',
  '--pkg', 'mcbpmf_api'], language: 'vala')

ibus_supports_focus_id = cc.compiles('''#include <ibus.h>
#if IBUS_CHECK_VERSION(1,5,27)
#else
#error FAIL
#endif
''',
  name: 'IBus supports focus ID',
  dependencies: ibus_dep)

if ibus_supports_focus_id
  add_project_arguments([
    '-D', 'IBUS_ENGINE_SUPPORTS_FOCUS_ID'], language: 'vala')
endif

# workaround to rebuild when any of local vapis are stale
local_vapis = custom_target(
  depend_files: ['mcbpmf_api.vapi'],
  command: ['touch', '@OUTPUT@'],
  output: '.ensure-vapis-up-to-date.vapi')

executable(
  engine_name,
  sources,
  local_vapis,
  include_directories: include_directories('../mcbopomofo-core/src'),
  install: true,
  install_dir: libexecdir,
  dependencies: dependencies,
)
