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
    this._prevCpu = null;
    this._prevNet = null;
    this._prevDisk = null;
    this._prevT = 0;
    this._iface = this._defaultIface();
    this._disk = this._rootDisk();
    this.set_applet_label('…');
    this._tick();
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

  _rootDisk: function() {
    try {
      let lines = this._read('/proc/mounts').split('\n');
      for (let l of lines) {
        let f = l.trim().split(/\s+/);
        if (f[1] === '/' && f[0].indexOf('/dev/') === 0) {
          let dev = f[0].replace('/dev/', '');
          // sda2 -> sda, nvme0n1p2 -> nvme0n1
          let m = dev.match(/^([a-z]+\d*n?\d*[a-z]*?)\d*[a-z]?\d*$/);
          let base = dev.replace(/p?\d+$/, '');
          return base || dev;
        }
      }
    } catch(e) {}
    return 'sda';
  },

  _fmtRate: function(bps) {
    if (bps < 1024) return Math.round(bps) + 'B';
    if (bps < 1048576) {
      let v = (bps / 1024).toFixed(1).replace(/\.0$/, '');
      return v + 'K';
    }
    let v = (bps / 1048576).toFixed(1).replace(/\.0$/, '');
    return v + 'M';
  },

  _fmtMem: function(kb) {
    if (kb < 1048576) return Math.round(kb / 1024) + 'M';
    return (kb / 1048576).toFixed(1).replace(/\.0$/, '') + 'G';
  },

  _tick: function() {
    try {
      let now = Date.now() / 1000;
      let dt = this._prevT > 0 ? (now - this._prevT) : 1;
      this._prevT = now;

      // --- CPU ---
      let cpuLine = this._read('/proc/stat').split('\n')[0].split(/\s+/).slice(1, 9).map(Number);
      let idle = cpuLine[3] + cpuLine[4];
      let total = cpuLine.reduce((a, b) => a + b, 0);
      let cpuPct = 0;
      if (this._prevCpu) {
        let dIdle = idle - this._prevCpu.idle, dTot = total - this._prevCpu.total;
        if (dTot > 0) cpuPct = Math.round(100 * (1 - dIdle / dTot));
      }
      this._prevCpu = { idle: idle, total: total };

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

      // --- DISK ---
      let rd = 0, wr = 0;
      for (let l of this._read('/proc/diskstats').split('\n')) {
        let f = l.trim().split(/\s+/);
        if (f[2] === this._disk) { rd = +f[5]; wr = +f[9]; }
      }
      let rdR = 0, wrR = 0;
      if (this._prevDisk) {
        rdR = Math.max(0, (rd - this._prevDisk.rd) * 512 / dt);
        wrR = Math.max(0, (wr - this._prevDisk.wr) * 512 / dt);
      }
      this._prevDisk = { rd: rd, wr: wr };

      this.set_applet_label(
        'CPU ' + cpuPct + '%  MEM ' + this._fmtMem(memUsed) +
        '  ▼' + this._fmtRate(downR) + ' ▲' + this._fmtRate(upR) +
        '  ⬇' + this._fmtRate(rdR) + ' ⬆' + this._fmtRate(wrR)
      );
    } catch(e) {}
    Mainloop.timeout_add_seconds(1, () => { this._tick(); return false; });
  }
};

function main(metadata, orientation, panelHeight, instanceId) {
  return new MyApplet(orientation, panelHeight, instanceId);
}
