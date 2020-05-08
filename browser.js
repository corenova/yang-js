'use strict';

const { Yang, Store, Model, Container, Property } = require('./lib');

// initialize with YANG 1.1 extensions and typedefs
Yang.use(require('./lib/lang/extensions'));
Yang.use(require('./lib/lang/typedefs'));

const parseYangSchema = (...args) => {
  const [ schema, spec ] = args.flat();
  return Yang.parse(schema).bind(spec);
}

exports = Yang;
exports.yang = parseYangSchema;
exports.Yang = Yang;
exports.Store = Store;
exports.Model = Model;
exports.Container = Container;
exports.Property = Property;

module.exports = global.Yang = exports;

