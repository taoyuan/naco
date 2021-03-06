"use strict";

var _ = require('lodash');
var fs = require('fs-extra');
var path = require('path');
var Yaml = require('yamljs');

var POSSIBLES = ['./', '../', '../../', '../../../', 'etc'];

module.exports = Settings;

/**
 *
 * @param arduino
 * @param file
 * @constructor
 */
function Settings(arduino, file) {
  if (!(this instanceof Settings)) {
    return new Settings(arduino, file);
  }
  this.arduino = arduino;

  this.file = file = findFile(file);
  if (file && fs.existsSync(file)) {
    this.import(arduino, readYaml(file));
  }
}

Settings.prototype.import = function (data) {
  Settings.import(this.arduino, data);
};

Settings.prototype.importFromString = function (string) {
  this.import(Yaml.parse(string));
};

Settings.prototype.export = function (data) {
  return Settings.export(this.arduino, data);
};

Settings.prototype.exportToString = function (data) {
  return Yaml.stringify(this.export(data), 4, 2)
};

Settings.prototype.save = function () {
  if (!this.file) return;
  var data = fs.existsSync(this.file) ? readYaml(this.file) : {};
  writeYaml(this.file, this.export(data));
};

Settings.import = function (arduino, data) {
  var context = arduino.context;
  if (data.board) {
    var board = arduino.select(data.board).board;
    var options = data.options || {};
    options = options[data.board];
    if (board && options) {
      _.forEach(options, function (value, key) {
        context.set('custom_' + key, board.id + '_' + value);
      });
    }
  }

  if (data.port) {
    if (_.startsWith(data.port, '/dev/')) {
      data.port = data.port.substring(5);
    }
    context.set('serial.port', data.port);
  }
};

Settings.export = function (arduino, data) {
  data = data || {};
  var context = arduino.context;

  if (arduino.board) {
    var board = arduino.board;
    data.board = board.vendor.id + ':' + board.platform.id + ':' + board.id;

    _.forEach(board.getMenuIds(), function (menuId) {
      if (!board.hasMenu(menuId)) return;

      var selectionId;
      // Get "custom_[MENU_ID]" preference (for example "custom_cpu")
      var entry = context.get('custom_' + menuId);

      if (entry && _.startsWith(entry, board.id)) {
        selectionId = entry.substring(board.id.length + 1);
      }

      // If no selection id, using first selection as default
      if (!selectionId) {
        selectionId = board.getDefaultSelectionId(menuId);
      }

      if (selectionId) {
        var options = data.options = data.options || {};
        options[data.board] = options[data.board] || {};
        options[data.board][menuId] = selectionId;
      }
    });
  }

  if (context.has('serial.port')) {
    data.port = context.get('serial.port');
  }
  return data;
};

function findFile(dir) {
  if (!fs.existsSync(dir)) {
    return;
  }
  var stats = fs.lstatSync(dir);
  if (stats.isFile()) {
    return dir;
  }
  if (!stats.isDirectory()) {
    return;
  }

  var rel = _.find(POSSIBLES, function (possible) {
    return fs.existsSync(path.resolve(dir, possible, 'iotor.yml'));
  });

  if (rel) {
    return path.resolve(dir, rel, 'iotor.yml');
  }
}

function readYaml(file) {
  return Yaml.parse(fs.readFileSync(file).toString());
}

function writeYaml(file, data) {
  fs.writeFileSync(file, Yaml.stringify(data, 4, 2));
}
