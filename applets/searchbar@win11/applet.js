const Applet = imports.ui.applet;
const AppletManager = imports.ui.appletManager;
const St = imports.gi.St;
const Clutter = imports.gi.Clutter;
const Main = imports.ui.main;

function MyApplet(orientation, panelHeight, instanceId) {
  this._init(orientation, panelHeight, instanceId);
}
MyApplet.prototype = {
  __proto__: Applet.TextIconApplet.prototype,
  _init: function(orientation, panelHeight, instanceId) {
    Applet.TextIconApplet.prototype._init.call(this, orientation, panelHeight, instanceId);
    this._entry = new St.Entry({
      hint_text: "Search",
      track_hover: true,
      can_focus: true,
      style_class: "searchbar-win11-entry"
    });
    // NOTE: St.Entry's internal handler consumes button-press events
    // (returns EVENT_STOP), so normally-connected 'button-press-event'
    // handlers never run. Use capture-phase 'captured-event' instead.
    // Open on RELEASE (not press): opening on press causes the same
    // click's release to immediately dismiss the menu again.
    this._entry.connect('captured-event', (actor, event) => {
      try {
        if (event.type() === Clutter.EventType.BUTTON_RELEASE) {
          this._triggerSearch(this._entry.get_text());
        }
      } catch(e) {}
      return Clutter.EVENT_PROPAGATE;
    });
    // Backup paths: if keystrokes ever reach this entry (e.g. while the
    // menu grab routes keys to the stage), mirror them into the menu.
    this._entry.clutter_text.connect('key-press-event', (actor, event) => {
      try {
        let symbol = event.get_key_symbol();
        let text = this._entry.get_text();
        if (symbol == 65293) { // Enter
          this._triggerSearch(text);
          return true;
        }
        if (text.length > 0) {
          this._triggerSearch(text);
        }
      } catch(e) {}
      return false;
    });
    this._entry.clutter_text.connect('text-changed', () => {
      try {
        let text = this._entry.get_text();
        if (text.length > 0) {
          this._triggerSearch(text, false);
        }
      } catch(e) {}
    });
    this.actor.add_actor(this._entry);
    this.actor.set_style("min-width: 200px;");
  },
  _findMenuApplet: function() {
    try {
      let instances = AppletManager.getRunningInstancesForUuid("menueleven@djb");
      if (instances && instances.length > 0) {
        return instances[0];
      }
    } catch(e) {}
    for (let panel of Main.panelManager.getPanels()) {
      if (!panel) continue;
      for (let box of [panel._leftBox, panel._centerBox, panel._rightBox]) {
        if (!box) continue;
        for (let actor of box.get_children()) {
          let app = actor._applet;
          if (app && (app._uuid === "menueleven@djb" || app.__uuid__ === "menueleven@djb")) {
            return app;
          }
        }
      }
    }
    return null;
  },
  _triggerSearch: function(text, focusMenuSearch) {
    if (focusMenuSearch === undefined) focusMenuSearch = true;
    let menuApplet = this._findMenuApplet();
    if (!menuApplet) return;
    if (menuApplet.menu && !menuApplet.menu.isOpen) {
      menuApplet.menu.open(true);
    }
    if (text !== undefined && menuApplet.display && menuApplet.display.searchView && menuApplet.display.searchView.searchEntry) {
      try {
        imports.mainloop.timeout_add(100, () => {
          try {
            let entry = menuApplet.display.searchView.searchEntry;
            if (entry) {
              if (text) entry.set_text(text);
              if (focusMenuSearch) entry.grab_key_focus();
            }
          } catch(e) {}
          return false;
        });
      } catch(e) {}
    } else if (menuApplet.display && menuApplet.display.searchView && menuApplet.display.searchView.searchEntry) {
      // No text yet: just focus the menu search so the user can type there
      try { menuApplet.display.searchView.searchEntry.grab_key_focus(); } catch(e) {}
    }
  },
  on_applet_clicked: function() {
    this._entry.grab_key_focus();
    this._triggerSearch(this._entry.get_text());
  }
};
function main(metadata, orientation, panelHeight, instanceId) {
  return new MyApplet(orientation, panelHeight, instanceId);
}
