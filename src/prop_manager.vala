namespace IBusMcBopomofo {
  public enum PropType {
    InputMode = 0,
    ShapeMode = 1;

    public static int maximum() {
      var klass = (EnumClass) typeof(PropType).class_ref();
      return klass.maximum;
    }
  }

  private enum PropTextType {
    LABEL = 0,
    SYMBOL = 1,
    TOOLTIP = 2
  }

  class PropManager : Object {
    public IBus.PropList props_list;

    private static IBus.Text[] input_mode_texts;
    private static IBus.Text[] symbol_mode_texts;
    private static IBus.Text empty_text;

    static construct {
      PropManager.empty_text = new IBus.Text.from_static_string("");

      PropManager.input_mode_texts = {
        new IBus.Text.from_string(C_("input_mode", "McBopomofo")),
        new IBus.Text.from_string(C_("input_mode", "McBopomofo - Plain")),
        new IBus.Text.from_string(C_("input_mode", "McBopomofo - P/T")),
        new IBus.Text.from_string(C_("input_mode", "Mc")),
        new IBus.Text.from_string(C_("input_mode", "Mc*")),
        new IBus.Text.from_string(C_("input_mode", "A")),
        new IBus.Text.from_string(_("Current input mode")),
        new IBus.Text.from_string(_("Toggle passthrough mode")),
      };

      PropManager.symbol_mode_texts = {
        new IBus.Text.from_string(C_("shape_mode", "Full shape")),
        new IBus.Text.from_string(C_("shape_mode", "Half shape")),
        new IBus.Text.from_string(C_("shape_mode", "\u25a0")),
        new IBus.Text.from_string(C_("shape_mode", "\u25e7")),
        new IBus.Text.from_string(_("Toggle full/half shape")),
      };
    }

    public PropManager() {
      this.props_list = new IBus.PropList();
      this.props_list.properties.set_size(PropType.maximum() + 1);

      IBus.Property prop;

      prop = new IBus.Property(
        "InputMode",
        IBus.PropType.NORMAL,
        PropManager.get_input_mode_text(PropTextType.LABEL, 0),
        null,  // Config.PKGDATADIR + "/icons/Bopomofo.png"
        PropManager.get_input_mode_text(PropTextType.TOOLTIP, 0),
        true,
        true,
        IBus.PropState.UNCHECKED,
        null);
      prop.symbol = PropManager.get_input_mode_text(PropTextType.SYMBOL, 0);
      this.props_list.properties.data[PropType.InputMode] = (owned) prop;

      prop = new IBus.Property(
        "ShapeMode",
        IBus.PropType.NORMAL,
        PropManager.get_symbol_mode_text(PropTextType.LABEL, 0),
        null,
        PropManager.get_symbol_mode_text(PropTextType.TOOLTIP, 0),
        true,
        true,
        IBus.PropState.UNCHECKED,
        null);
      prop.symbol = PropManager.get_symbol_mode_text(PropTextType.SYMBOL, 0);
      this.props_list.properties.data[PropType.ShapeMode] = (owned) prop;
    }

    private static unowned IBus.Text get_input_mode_text(PropTextType type, int offset) {
      return PropManager.input_mode_texts[((int) type) * 3 + offset];
    }
    private static unowned IBus.Text get_symbol_mode_text(PropTextType type, int offset) {
      return PropManager.symbol_mode_texts[((int) type) * 2 + offset];
    }

    public unowned IBus.Property index(PropType t) {
      return this.props_list.properties.index(t) as IBus.Property;
    }

    public IBus.Property update_input_mode(int kind) {
      var prop = this.index(PropType.InputMode);
      prop.set_label(PropManager.get_input_mode_text(PropTextType.LABEL, kind));
      prop.set_symbol(PropManager.get_input_mode_text(PropTextType.SYMBOL, kind));
      prop.set_tooltip(PropManager.get_input_mode_text(PropTextType.TOOLTIP, 0));
      return prop;
    }
  }
}
