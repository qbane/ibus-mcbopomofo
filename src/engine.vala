unowned EnumValue? get_enum_from_variant(Type enum_type, Variant variant) {
  unowned string nick = variant.get_string();
  EnumClass enumc = (EnumClass) enum_type.class_ref();
  return enumc.get_value_by_nick(nick);
}

sealed class IBusMcBopomofo.Engine : IBus.Engine {
  public static IBus.Bus? bus;
  public static string? builtin_lm_dir;
  public static string? user_data_dir;
  private static Settings m_panel_settings;
  private static Settings m_engine_settings;

  private McbpmfApi.Core core;
  private IBusMcBopomofo.BusWatcher m_bus_watcher;
  private IBusMcBopomofo.PropManager m_prop_manager;

  private bool m_props_registered = false;
  private bool m_language_model_loaded = false;

  private uchar m_last_pressed_is_shift = 0;
  private bool m_force_passthrough = false;

  private uint[] selection_keys;
  private string[] selection_labels;
  private IBus.LookupTable? lookup_table;

  // enable shift to switch passthrough mode temporarily
  public bool passthrough_switch_enabled { get; set construct; }
  public int lookup_table_orientation { get; set; }
  public bool is_passthrough_mode { get; private set; }
  public bool use_inline_caret { get; set; }

  // the actual page size, set to the minimum of
  // cand-per-page from dconf and selection_keys.length
  private int _page_size;
  // TODO: make this configurable
  public int page_size {
    get { return this._page_size; }
    set construct {
      this._page_size = int.min(value, selection_keys.length).clamp(2, 16);
    }
  }

  // TODO
  public string selection_keys_str {
    get; set;
  }

  private static uint[] _mkeysList = {
    IBus.KEY_Left,
    IBus.KEY_Right,
    IBus.KEY_Up,
    IBus.KEY_Down,
    IBus.KEY_Home,
    IBus.KEY_End,
  };

  static construct {
    m_panel_settings = new Settings("org.freedesktop.ibus.panel");
    m_engine_settings = new Settings("org.openVanilla.McBopomofo");
  }

  construct {
#if IBUS_ENGINE_SUPPORTS_FOCUS_ID
    this.has_focus_id = true;
#endif

    info("construct engine_name=[%s], object_path=[%s]!", this.engine_name, this.object_path);

    this.m_bus_watcher = new BusWatcher(this.connection);
    this.m_prop_manager = new PropManager();
    this.core = new McbpmfApi.Core();

    debug("this.core.input_mode=%s", this.core.input_mode.to_string());
    this.bind_settings();
    Engine.m_engine_settings.changed.connect(this.on_settings_changed);
    Engine.m_panel_settings.bind("lookup-table-orientation", this, "lookup-table-orientation", SettingsBindFlags.DEFAULT);

    if (Engine.builtin_lm_dir == null) {
      warning("Path to built-in language model is empty!!");
    } else {
      string db_fname = Path.build_filename(Engine.builtin_lm_dir, "mcbopomofo-data.txt");
      bool success = this.core.load_model(db_fname);
      if (!success) {
        warning("Cannot load built-in language model at %s!!", db_fname);
      } else {
        m_language_model_loaded = true;
      }
    }

    this.core.custom_phrase_added.connect((reading, s) => {
      info("Custom phrase added --> [%s] (reading=%s)", s, reading);
    });

    this.init_lookup_table();
  }

  public override void destroy() {
    info("destroy!");
    this.m_bus_watcher.dispose();
    base.destroy();
  }

  private void bind_settings() {
    Engine.m_engine_settings.bind("passthrough-switch-enabled",
      this, "passthrough-switch-enabled", SettingsBindFlags.GET);

    Engine.m_engine_settings.bind("use-inline-caret",
      this, "use-inline-caret", SettingsBindFlags.GET);

    Engine.m_engine_settings.bind_with_mapping("keyboard-layout",
      this.core, "keyboard-layout", SettingsBindFlags.GET,
      (val_dest, variant) => {
        var enumv = get_enum_from_variant(typeof(McbpmfApi.KeyboardLayout), variant);
        if (enumv == null) {
          return false;
        }
        val_dest.set_enum(enumv.value);
        return true;
      }, (SettingsBindSetMappingShared) null, null, null);

    Engine.m_engine_settings.bind_with_mapping("select-phrase",
      this.core, "select-cand-after-cursor", SettingsBindFlags.GET,
      (val_dest, variant) => {
        val_dest.set_boolean(variant.get_string() == "after-cursor");
        return true;
      }, (SettingsBindSetMappingShared) null, null, null);

    Engine.m_engine_settings.bind("auto-advance-cursor",
      this.core, "auto-advance-cursor", SettingsBindFlags.GET);

    Engine.m_engine_settings.bind_with_mapping("behavior-shift-letter-keys",
      this.core, "put-lcase-letters-to-buffer", SettingsBindFlags.GET,
      (val_dest, variant) => {
        val_dest.set_boolean(variant.get_string() == "put-lowercase-to-buffer");
        return true;
      }, (SettingsBindSetMappingShared) null, null, null);

    Engine.m_engine_settings.bind("esc-clears-buffer",
      this.core, "esc-clears-buffer", SettingsBindFlags.GET);

    Engine.m_engine_settings.bind_with_mapping("behavior-ctrl-enter-key",
      this.core, "ctrl-enter-behavior", SettingsBindFlags.GET,
      (val_dest, variant) => {
        var enumv = get_enum_from_variant(typeof(McbpmfApi.CtrlEnterBehavior), variant);
        if (enumv == null) {
          return false;
        }
        val_dest.set_enum(enumv.value);
        return true;
      }, (SettingsBindSetMappingShared) null, null, null);
  }

  private void on_settings_changed(string key) {
    warning("Setting [%s] changed!", key);
  }

  private void init_lookup_table() {
    // TODO: make page size configurable
    // 20~7e are directly mapped to ASCII
    this.selection_keys = {
      IBus.KEY_1,
      IBus.KEY_2,
      IBus.KEY_3,
      IBus.KEY_4,
      IBus.KEY_5,
      IBus.KEY_6,
      IBus.KEY_7,
      IBus.KEY_8,
      IBus.KEY_9,
      IBus.KEY_0,
    };
    this.page_size = 8;
    this.lookup_table = new IBus.LookupTable(this.page_size, 0, true, false);

    for (int i = 0; i < this._page_size; i++) {
      this.selection_labels += @"$(i+1).";
      this.lookup_table.set_label(i, new IBus.Text.from_static_string(this.selection_labels[i]));
    }
  }

  private bool is_choosing_candidate() {
    var curState = this.core.get_state();
    return curState.get_type() == McbpmfApi.InputStateType.CANDIDATES;
  }

  private void update_prop(PropType mode) {
    switch (mode) {
    case PropType.InputMode:
      bool passing = this.m_force_passthrough || this.is_passthrough_mode;
      int kind;

      if (passing) {
        kind = 2;
      } else {
        // TODO: plain mcbopomofo
        kind = 0;
      }

      this.update_property(this.m_prop_manager.update_input_mode(kind));
      break;
    default:
      warning("Invalid PropType %d", mode);
      break;
    }
  }

  private McbpmfApi.KeyDef encode_key(uint keyval, uint modifiers) {
    // encode (keyval, mods)
    char ascii = 0;
    if (keyval < 0x7f) {
      ascii = (char) keyval;
    } else if (keyval == IBus.KEY_BackSpace) {
      ascii = 8;
    } else if (keyval == IBus.KEY_Tab) {
      ascii = 9;
    } else if (keyval == IBus.KEY_Return) {
      ascii = 13;
    } else if (keyval == IBus.KEY_Escape) {
      ascii = 27;
    } else if (keyval == IBus.KEY_Delete) {
      ascii = 127;
    }

    uchar mods = 0;
    if ((IBus.ModifierType.SHIFT_MASK & modifiers) != 0) mods |= McbpmfApi.KeyModifiers.SHIFT_MASK;
    if ((IBus.ModifierType.CONTROL_MASK & modifiers) != 0) mods |= McbpmfApi.KeyModifiers.CTRL_MASK;

    if (ascii != 0) {
      return new McbpmfApi.KeyDef.ascii(ascii, mods);
    } else {
      int mkey;
      // mkey=0 is for ascii keys; if no match, the key will be UNKNOWN
      for (mkey = 1; mkey < _mkeysList.length; mkey++) {
        if (keyval == _mkeysList[mkey - 1]) {
          break;
        }
      }
      return new McbpmfApi.KeyDef.named(mkey, mods);
    }
  }

  private void move_candidate_cursor(bool page, bool reverse, bool forward_wrap = false) {
    var cur = this.lookup_table.get_cursor_pos();
    var max = this.lookup_table.get_number_of_candidates();
    var sz = this.page_size;

    var curOrig = cur;
    if (!page) {
      if (!reverse && cur != max - 1) cur++;
      else if (reverse && cur != 0) cur--;
    } else {
      var curPage = cur / sz;
      if (!reverse) {
        var numPages = (max + sz - 1) / sz;
        if (curPage < numPages - 1) {
          cur = (curPage + 1) * sz;
        } else if (forward_wrap) {
          cur = 0;
        }
      } else if (reverse && curPage != 0) {
        cur = (curPage - 1) * sz;
      }
    }

    if (curOrig != cur) {
      this.lookup_table.set_cursor_pos(cur);
      this.update_lookup_table(this.lookup_table, true);
      debug("Lookup table cursor %u -> %u", curOrig, this.lookup_table.get_cursor_pos());
    }
  }

  private void handle_candidate_chooser(uint keyval, uint modifiers, out McbpmfApi.InputState? next) {
    // check for selection keys (only valid if in range)
    for (int i = 0; i < this.page_size; i++) {
      // TODO: press shift/ctrl+x to select
      if (keyval == this.selection_keys[i] && modifiers == 0) {
        var cur = this.lookup_table.get_cursor_pos();
        var bas = cur / this.page_size * this.page_size;
        var target = bas + i;
        if (target < this.lookup_table.get_number_of_candidates()) {
          assert(this.core.select_candidate((int) target, out next));
          return;
        }
      }
    }

    if (keyval == IBus.KEY_Return) {
      assert(this.core.select_candidate((int) this.lookup_table.get_cursor_pos(), out next));
      return;
    }

    if (keyval == IBus.KEY_Escape || keyval == IBus.KEY_BackSpace) {
      // dismiss the candidate window
      assert(this.core.select_candidate(-1, out next));
      return;
    }

    if (keyval == IBus.KEY_space) {
      // next page & wrap around if at last page
      this.move_candidate_cursor(true, false, true);
    }

    var ori = this.lookup_table.get_orientation();
    bool isVertical = ori == IBus.Orientation.VERTICAL ||
      (ori == IBus.Orientation.SYSTEM && this.lookup_table_orientation == 1);

    // in vertical, L/R are for pages, and vice versa
    if (keyval == IBus.KEY_Left) {
      this.move_candidate_cursor(isVertical, true);
    } else if (keyval == IBus.KEY_Right) {
      this.move_candidate_cursor(isVertical, false);
    } else if (keyval == IBus.KEY_Up) {
      this.move_candidate_cursor(!isVertical, true);
    } else if (keyval == IBus.KEY_Down) {
      this.move_candidate_cursor(!isVertical, false);
    }

    // TODO: core::handleCandidateKeyForTraditionalBompomofoIfRequired

    // navigations never mutate state
    next = null;
  }

  private bool handle_general_key(McbpmfApi.KeyDef key, out McbpmfApi.InputState? next) {
    bool error;
    bool accepted = this.core.handle_key(key, out next, out error);

    if (error) {
      warning("Error occurs when transitioning");
    }
    if (!accepted) {
      debug("PASSTHROUGH");
      return false;
    }
    // If accepted is true, the key is absorbed
    if (next == null) {
      debug("REJECT");
    }
    return true;
  }

  public override bool process_key_event(uint keyval, uint keycode, uint modifiers) {
    if (m_force_passthrough) {
      return false;
    }

    var ignoreMask = (
      IBus.ModifierType.MOD1_MASK |   // alt is mod1, not meta
      IBus.ModifierType.SUPER_MASK |
      IBus.ModifierType.LOCK_MASK);

    if ((modifiers & ignoreMask) != 0) {
      return false;
    }
    debug("key event %s (val=0x%x, code=%u)", IBus.key_event_to_string(keyval, modifiers), keyval, keycode);

    bool isReleasing = (IBus.ModifierType.RELEASE_MASK & modifiers) != 0;

    // the only scenerio we need to deal with key releasing is to toggle passthrough mode
    if (isReleasing) {
      if ((this.m_last_pressed_is_shift == 1 && keyval == IBus.KEY_Shift_L) ||
          (this.m_last_pressed_is_shift == 2 && keyval == IBus.KEY_Shift_R)) {
        this.m_last_pressed_is_shift = 0;
        this.is_passthrough_mode = !this.is_passthrough_mode;
        debug("[[ passthrough mode is %s ]]", this.is_passthrough_mode ? "on" : "off");
        this.update_prop(PropType.InputMode);
        // preedit buffer is lost when passthrough mode is turned on
        this.core.reset_state();
        this.update_view(null);
        return true;
      }
      // FIXME: If a key is absorbed, its releasing event should also be absorbed.
      // Otherwise, e.g., a Esc-dismissed prompt may pick it up.
      return false;
    }

    if (this.passthrough_switch_enabled && this.m_last_pressed_is_shift == 0) {
      var otherMods = IBus.ModifierType.CONTROL_MASK | IBus.ModifierType.MOD1_MASK;
      if (!isReleasing && (modifiers & otherMods) == 0) {
        if (keyval == IBus.KEY_Shift_L) {
          this.m_last_pressed_is_shift = 1;
        } else if (keyval == IBus.KEY_Shift_R) {
          this.m_last_pressed_is_shift = 2;
        }
      }
    } else {
      this.m_last_pressed_is_shift = 0;
    }

    if (this.is_passthrough_mode) {
      return false;
    }

    McbpmfApi.InputState? next;
    bool accepted;

    if (this.is_choosing_candidate()) {
      var knownCombKeys = IBus.ModifierType.SHIFT_MASK | IBus.ModifierType.CONTROL_MASK | IBus.ModifierType.MOD1_MASK;
      this.handle_candidate_chooser(keyval, modifiers & knownCombKeys, out next);
      // the default is to absorb all keys
      accepted = true;
    } else {
      if (keyval == IBus.KEY_Shift_L || keyval == IBus.KEY_Shift_R ||
          keyval == IBus.KEY_Control_L || keyval == IBus.KEY_Control_R) {
        // XXX: do not send out pure shift/ctrl
        accepted = false;
        next = null;
      } else {
        var key = this.encode_key(keyval, modifiers);
        accepted = this.handle_general_key(key, out next);
      }
    }

    if (next != null) {
      this.update_view(next);
      if (next.get_type() == McbpmfApi.InputStateType.EIP) {
        this.core.reset_state(false);
      } else {
        this.core.set_state(next);
      }
    }

    return accepted;
  }

  private void update_view(McbpmfApi.InputState? state) {
    McbpmfApi.InputStateType stateType = state != null ? state.get_type() : McbpmfApi.InputStateType.EMPTY;
    debug("update_view: state type=%s", stateType.to_string());

    unowned string? prevBuf = null;
    if (stateType == McbpmfApi.InputStateType.EMPTY) {
      McbpmfApi.InputState? prevState = this.core.get_state();
      prevBuf = (string?) prevState.peek_buf();
    }

    bool showBuffer = false;
    switch (stateType) {
    case McbpmfApi.InputStateType.EMPTY:
      if (prevBuf != null) {
        var text = new IBus.Text.from_string(prevBuf);
        this.commit_text(text);
      }
      break;

    case McbpmfApi.InputStateType.EIP:
      break;

    case McbpmfApi.InputStateType.INPUTTING:
      showBuffer = true;
      break;

    case McbpmfApi.InputStateType.COMMITTING:
      unowned string? buf = (string?) state.peek_buf();
      assert_nonnull(buf);
      var text = new IBus.Text.from_string(buf);
      this.commit_text(text);
      break;

    case McbpmfApi.InputStateType.CANDIDATES:
      showBuffer = true;
      GenericArray<string>? cs = state.get_candidates();
      assert_nonnull(cs);
      var table = this.lookup_table;
      table.clear();

      // XXX: gnome's "SYSTEM" orientation is vertical, regardless of what
      // is specified in dconf, so be explicit here
      if (table.get_orientation() == IBus.Orientation.SYSTEM) {
        table.set_orientation(this.lookup_table_orientation == 1 ?
          IBus.Orientation.VERTICAL : IBus.Orientation.HORIZONTAL);
      }

      // TODO: In McBopomofo.cpp there is a disambiguation feature:
      // > Construct the candidate list with special care for candidates that have
      // > the same values.

      for (int i = 0; i < cs.length; i += 2) {
        // the reading is irrevalent
        table.append_candidate(new IBus.Text.from_static_string(cs[i+1]));
      }

      // idea: jump to the candidate last chosen
      // it seems that McBmpfApi does not do this, but not confirmed

      this.lookup_table = table;
      this.update_lookup_table(table, true);
      break;

    case McbpmfApi.InputStateType.MARKING:
      showBuffer = true;
      // TODO: use exclusive logic to draw preedit text
      break;
    }

    if (stateType != McbpmfApi.InputStateType.CANDIDATES) {
      this.hide_lookup_table();
    }

    if (showBuffer && !this.m_language_model_loaded) {
      var str = _("Warning: The language model for %s is not loaded.\nPlease check the installation.").printf(_("McBopomofo"));
      var text = new IBus.Text.from_string(str);
      this.update_auxiliary_text(text, true);
    } else {
      unowned string rtipBuf = showBuffer ? state.peek_tooltip() : null;
      if (rtipBuf != null && rtipBuf[0] != '\0') {
        var text = new IBus.Text.from_string(rtipBuf);
        this.update_auxiliary_text(text, true);
      } else {
        this.hide_auxiliary_text();
      }
    }

    this.sync_preedit_from_state(state);
  }

  private void sync_preedit_from_state(McbpmfApi.InputState? state) {
    if (state == null) {
      this.hide_preedit_text();
      this.hide_auxiliary_text();
      this.hide_lookup_table();
      return;
    }

    char* rawBuf = state.peek_buf();
    if (rawBuf == null) {
      this.hide_preedit_text();
      return;
    }

    unowned string buf = (string) rawBuf;
    var curoffs = state.peek_index();
    // iff. committing
    if (curoffs < 0) {
      this.hide_preedit_text();
      return;
    }
    // assert(curoffs >= 0);
    // convert curoffs to num of char
    var curpos = buf.char_count(curoffs);
    var len = curpos + buf.offset(curoffs).char_count();

    string preeditStr = buf;
    IBus.Text preedit;

    // when preedit text is embedded, it is fine without any decoration
    bool drawCursor = !this.m_bus_watcher.embed_preedit_text;
    bool insertInlineCaret = drawCursor && this.use_inline_caret;
    if (insertInlineCaret) {
      // from ibus-rime, split the buffer at cursor
      StringBuilder sb = new StringBuilder(preeditStr);
      sb.insert(curoffs, "\u2038");
      preedit = new IBus.Text.from_string(sb.str);
    } else {
      // highlight the character after cursor
      // if cursor is at end, insert a space so that at least the cursor is visible
      // TODO: mark the currently composing phonemes
      if (len == curpos && drawCursor) {
        // hair space
        preeditStr += "\u200a";
      }
      preedit = new IBus.Text.from_string(preeditStr);
      var attrs = new IBus.AttrList();
      attrs.append(new IBus.Attribute(IBus.AttrType.UNDERLINE, IBus.AttrUnderline.SINGLE, 0, len));

      if (drawCursor) {
        // copied from ibus-chewing
        attrs.append(new IBus.Attribute(IBus.AttrType.BACKGROUND, 0x00c8c8f0, curpos, curpos + 1));
        attrs.append(new IBus.Attribute(IBus.AttrType.FOREGROUND, 0x0, curpos, curpos + 1));
      }

      preedit.set_attributes((owned) attrs);
    }

    this.update_preedit_text(preedit, curpos, true);
  }

#if IBUS_ENGINE_SUPPORTS_FOCUS_ID
  public override void focus_in_id(string ic_path, string client_name) {
    info("focus_in! ic=[%s], client=[%s]", ic_path, client_name);
    this.focus_in();
    /* extra logic */
  }
#endif

  public override void focus_in() {
#if !IBUS_ENGINE_SUPPORTS_FOCUS_ID
    info("focus_in!");
#endif
    if (!m_props_registered) {
      this.register_properties(this.m_prop_manager.props_list);
      m_props_registered = true;
    }
  }

#if IBUS_ENGINE_SUPPORTS_FOCUS_ID
  public override void focus_out_id(string ic_path) {
    info("focus_out! ic=[%s]", ic_path);
    this.focus_out();
    /* extra logic */
  }
#endif

  public override void focus_out() {
#if !IBUS_ENGINE_SUPPORTS_FOCUS_ID
    info("focus_out!");
#endif
    m_props_registered = false;
    this.core.reset_state();
    this.update_view(null);
  }

  public override void reset() {
    info("reset!");
  }

  public override void enable() {
    info("enable!");
  }

  public override void disable() {
    info("disable!");
  }

  public override void page_up() {
    if (this.is_choosing_candidate()) {
      this.move_candidate_cursor(true, true);
    }
  }

  public override void page_down() {
    if (this.is_choosing_candidate()) {
      this.move_candidate_cursor(true, false);
    }
  }

  public override void cursor_up() {
    info("cursor_up!");
    if (this.is_choosing_candidate()) {
      this.move_candidate_cursor(true, true);
    }
  }

  public override void cursor_down() {
    info("cursor_down!");
    if (this.is_choosing_candidate()) {
      this.move_candidate_cursor(true, false);
    }
  }

  public override void candidate_clicked(uint index, uint button, uint modifiers) {
    info("candidate_clicked %u %u %u!", index, button, modifiers);
    if (button == 1) {
      uint curpos = this.lookup_table.get_cursor_pos();
      uint bas = curpos / this.page_size * this.page_size;
      int tar = (int) (bas + index);

      if (index != curpos % this.page_size) {
        this.lookup_table.set_cursor_pos(tar);
        this.update_lookup_table(this.lookup_table, true);
        return;
      }
      McbpmfApi.InputState? next;
      assert(this.core.select_candidate(tar, out next));
      this.core.set_state(next);
      this.update_view(next);
    }
  }

  public override void property_activate(string prop_name, uint prop_state) {
    info("property_activate! [%s] [%u]", prop_name, prop_state);
    if (prop_name == "InputMode") {
      if (!this.m_force_passthrough) {
        this.is_passthrough_mode = !this.is_passthrough_mode;
        this.update_prop(PropType.InputMode);
      }
    }
  }

  public override void property_show(string prop_name) {
    info("property_show [%s]!", prop_name);
  }

  public override void property_hide(string prop_name) {
    info("property_hide [%s]!", prop_name);
  }

  // public override void set_cursor_location(int x, int y, int w, int h) {
  //   info("set_cursor_location %d %d %d %d!", x, y, w, h);
  // }

  public override void set_capabilities(uint caps) {
    info("set_capabilities %u!", caps);
  }

  // need to be enabled explicitly
  // public override void set_surrounding_text(Object _text, uint cursor_index, uint anchor_pos)  {
  //   var text = (IBus.Text) _text;
  //   info("set_surrounding_text %s %u %u!", text.text, cursor_index, anchor_pos);
  //   base.set_surrounding_text(_text, cursor_index, anchor_pos);
  // }

  public override void set_content_type(uint purpose, uint hints) {
    info("set_content_type %u %u!", purpose, hints);
    if (purpose == IBus.InputPurpose.PASSWORD ||
        purpose == IBus.InputPurpose.PIN) {
      this.m_force_passthrough = true;
    } else {
      this.m_force_passthrough = false;
    }
    this.update_prop(PropType.InputMode);
  }
}
