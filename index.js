const { Yang, Store, Model, Container, Property } = require('./lib');

// initialize with YANG 1.1 extensions and typedefs
Yang.use(require('./lib/lang/extensions'));
Yang.use(require('./lib/lang/typedefs'));

// extend with NodeJS filesystem related capabilities
Yang.resolve = require('./lib/node').resolve;
Yang.import = require('./lib/node').import;

// automatically register if require.extensions available
// may be deprecated in the future but hasn't happened in a while...
if (require.extensions && !require.extensions['.yang']) {
  require.extensions['.yang'] = (m, filename) => {
    m.exports = Yang.import(filename);
  };
}

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

module.exports = exports;
