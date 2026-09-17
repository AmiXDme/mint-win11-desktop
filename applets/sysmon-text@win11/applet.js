const Applet = imports.ui.applet;
const St = imports.gi.St;
const GLib = imports.gi.GLib;
const Mainloop = imports.mainloop;

function MyApplet(orientation, panelHeight, instanceId) {
  this._init(orientation, panelHeight, instanceId);
}

MyApplet.prototype = {
  __proto__: Applet.TextApplet.prototype,

  _init: function(orientation, panelHeight, instanceId) {
    Applet.TextApplet.prototype._init.call(this, orientation, panelHeight, instanceId);
    this.actor.style_class = 'sysmon-text-label';
    // Monospace + padded fields = constant pixel width, so the readout
    // never resizes and pinned taskbar icons stay put.
    // (TextApplet nests the St.Label in a StBin inside the box actor.)
    try {
      let kids = this.actor.get_children();
      let lbl = (kids && kids.length) ? kids[0].get_child() : null;
      if (!lbl) lbl = (kids && kids.length) ? kids[0] : null;
      if (lbl && lbl.set_style) lbl.set_style('font-family: monospace;');
    } catch(e) {}
    this._prevNet = null;
    this._prevT = 0;
    this._iface = this._defaultIface();
    this.set_applet_label('…');
    this._tick();       // instant first paint
    this._startLoop();  // then realtime repeat
  },

  _read: function(path) {
    try { return String(GLib.file_get_contents(path)[1]); }
    catch(e) { return ''; }
  },

  _defaultIface: function() {
    try {
      let lines = this._read('/proc/net/route').split('\n');
      for (let l of lines) {
        let f = l.trim().split(/\s+/);
        if (f[1] === '00000000' && f[0] !== 'Iface') return f[0];
      }
    } catch(e) {}
    return 'enp2s0';
  },

  _fmtRate: function(bps) {
    let s;
    if (bps < 1024) s = Math.round(bps) + 'B';
    else if (bps < 1048576) s = (bps / 1024).toFixed(1).replace(/\.0$/, '') + 'K';
    else s = (bps / 1048576).toFixed(1).replace(/\.0$/, '') + 'M';
    // Fixed width: pad to 6 chars so layout never shifts.
    while (s.length < 6) s = ' ' + s;
    return s;
  },

  _fmtMem: function(kb) {
    let s;
    if (kb < 1048576) s = Math.round(kb / 1024) + 'M';
    else s = (kb / 1048576).toFixed(1).replace(/\.0$/, '') + 'G';
    while (s.length < 5) s = ' ' + s;
    return s;
  },

  _tick: function() {
    try {
      let now = Date.now() / 1000;
      let dt = this._prevT > 0 ? (now - this._prevT) : 1;
      this._prevT = now;

      // --- MEM ---
      let memTotal = 0, memAvail = 0;
      for (let l of this._read('/proc/meminfo').split('\n')) {
        if (l.indexOf('MemTotal:') === 0) memTotal = parseInt(l.replace(/[^0-9]/g, ''), 10);
        else if (l.indexOf('MemAvailable:') === 0) memAvail = parseInt(l.replace(/[^0-9]/g, ''), 10);
      }
      let memUsed = memTotal - memAvail;

      // --- NET ---
      let down = 0, up = 0;
      for (let l of this._read('/proc/net/dev').split('\n')) {
        let m = l.trim().match(/^([^:]+):\s*(.+)$/);
        if (m && m[1] === this._iface) {
          let f = m[2].trim().split(/\s+/).map(Number);
          down = f[0]; up = f[8];
        }
      }
      let downR = 0, upR = 0;
      if (this._prevNet) {
        downR = Math.max(0, (down - this._prevNet.down) / dt);
        upR = Math.max(0, (up - this._prevNet.up) / dt);
      }
      this._prevNet = { down: down, up: up };

      this.set_applet_label(
        'MEM ' + this._fmtMem(memUsed) +
        ' ▼' + this._fmtRate(downR) + ' ▲' + this._fmtRate(upR)
      );
    } catch(e) {}
    // Realtime: 4 updates/sec. timeout_add repeats while we return true.
    return true;
  },

  _startLoop: function() {
    Mainloop.timeout_add(500, () => this._tick());
  }
};

function main(metadata, orientation, panelHeight, instanceId) {
  return new MyApplet(orientation, panelHeight, instanceId);
}
