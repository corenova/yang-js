'use strict';

const { Yang, Store, Model, Container, Property } = require('./lib');

// initialize with YANG 1.1 extensions and typedefs
Yang.use(require('./lib/lang/extensions'));
Yang.use(require('./lib/lang/typedefs'));

// expose key class entities
Yang.Store = Store;
Yang.Model = Model;
Yang.Container = Container;
Yang.Property = Property;

module.exports = global.Yang = Yang;

