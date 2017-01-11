YANG Parser
===========

This is a parser for the YANG data modelling language ([RFC 6020](http://tools.ietf.org/html/rfc6020)). It is written in CoffeeScript using the [Comparse](https://www.npmjs.com/package/comparse) functional parsing library.

So far, the parser only does lexical analysis using the rules of RFC 6020. That is, the `parse` function returns an object representing the tree of YANG statements without doing any syntactic or semantic checks.

The annotated CoffeeScript source is [here](https://gitlab.labs.nic.cz/labs/yang-tools/wikis/coffee_parser).

License
-------

Copyright © 2014 Ladislav Lhotka, CZ.NIC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


Installation
------------

For a global installation, run

    npm install -g yang-parser

Root privileges (`sudo`) might be needed.

Leave off `-g` if you prefer a local installation.

