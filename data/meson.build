ibus_desc_xml = 'mcbopomofo.xml'
configure_file(
  input: ibus_desc_xml + '.in',
  output: ibus_desc_xml,
  install_dir: datadir / 'ibus/component',
  configuration: configurations)

# TODO
mcbpmf_gschema = 'org.freedesktop.IBus.McBopomofo.gschema.xml'
configure_file(
  input: mcbpmf_gschema + '.in',
  output: mcbpmf_gschema,
  install: false,
  install_dir: datadir / 'glib-2.0/schemas',
  configuration: configurations)

setup_desktop_file = 'ibus-setup-mcbopomofo.desktop'
# TODO

install_subdir('icons', install_dir: pkgdatadir)

meson.add_install_script('copy_from_upstream.sh', '../mcbopomofo-core', pkgdatadir)
