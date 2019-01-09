'use strict';

const { Yang, Store, Model, Property } = require('./lib');

// initialize with YANG 1.1 extensions and typedefs
Yang.use(require('./lib/lang/extensions'));
Yang.use(require('./lib/lang/typedefs'));

// expose key class entities
Yang.Store = Store;
Yang.Model = Model;
Yang.Property = Property;

module.exports = Yang;

// automatically register if require.extensions available
if (require.extensions)
  require.extensions['.yang'] = (m, filename) => { m.exports = Yang.import(filename) }
