const { Yang, Store, Model, Container, Property } = require('./lib');

// initialize with YANG 1.1 extensions and typedefs
Yang.use(require('./lib/lang/extensions'));
Yang.use(require('./lib/lang/typedefs'));

// expose key class entities
Yang.Store = Store;
Yang.Model = Model;
Yang.Container = Container;
Yang.Property = Property;

// extend with NodeJS filesystem related capabilities
const NodeUtils = require('./lib/node');
Yang.resolve = NodeUtils.resolve;
Yang.import = NodeUtils.import;

// automatically register if require.extensions available
// may be deprecated in the future but hasn't happened in a while...
if (require.extensions && !require.extensions['.yang']) {
  require.extensions['.yang'] = (m, filename) => {
    m.exports = Yang.import(filename);
  };
}

module.exports = Yang;
