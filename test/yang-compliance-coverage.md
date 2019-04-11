## Current RFC 6020 Implementation Coverage

The below table provides up-to-date information about various YANG
schema language extensions and associated support within this module.
All extensions are syntactically and lexically processed already, but
the below table provides details on the status of extensions as it
pertains to how it is **processed** by the compiler for implementing
the intended behavior of each extension.

Basically, note that the *unsupported* status below indicates it is
not compliant with expected behavior although it is properly parsed
and processed by the compiler.

Most of the *supported* extensions and typedefs have a corresponding
*test case* reference link which will contain the associated mocha
test suite which contains the validation tests.

### Language Extensions

extension | status | notes
--- | --- | ---
action     | supported | v1.1 draft
anydata    | unsupported | semantic parsing only
anyxml     | unsupported | no plans to support this extension
augment    | supported | [test case 1](./extensions/module.coffee) [test case 2](./extensions/grouping.coffee)
base       | supported | identity reference verification
belongs-to | supported | resolve prefix
bit        | unsupported | TBD (0.17)
case       | supported | [test case](./extensions/choice.coffee)
choice     | supported | [test case](./extensions/choice.coffee)
config     | supported | [test case](./extensions/leaf.coffee)
contact    | supported | meta data only
container  | supported | [test case](./extensions/container.coffee)
default    | supported | [test case](./extensions/leaf.coffee)
description     | supported   | meta data only
deviate         | unsupported | TBD merge/alter
deviation       | unsupported  | TBD merge/alter
enum            | suported    | [test case](./extensions/type.coffee)
error-app-tag   | unsupported | TBD (0.16)
error-message   | unsupported | TBD (0.16)
feature         | supported | enable feature binding (test case TBD)
fraction-digits | supported | [test case](./extensions/type.coffee)
grouping   | supported | [test case](./extensions/grouping.coffee)
identity   | supported | [test case](./extensions/module.coffee)
if-feature | supported | conditional verification on feature binding
import     | supported | [test case](./extensions/import.coffee)
include    | supported | [test case](./extensions/import.coffee)
input      | supported | [test case](./extensions/rpc.coffee)
key        | supported | [test case](./extensions/list.coffee)
leaf       | supported | [test case](./extensions/leaf.coffee)
leaf-list  | supported | [test case](./extensions/leaf-list.coffee)
length     | supported | [test case](./extensions/type.coffee)
list       | supported | [test case](./extensions/list.coffee)
mandatory  | supported | [test case](./extensions/leaf.coffee)
max-elements | supported | [test case](./extensions/leaf-list.coffee)
min-elements | supported | [test case](./extensions/leaf-list.coffee)
modifier   | unsupported | v1.1 draft - TBD
module     | supported | [test case](./extensions/module.coffee)
must       | unsupported | TBD
namespace  | supported | meta data only
notification | unsupported | TBD
ordered-by   | unsupported | TBD
organization | supported | meta data only
output     | supported | [test case](./extensions/rpc.coffee)
path       | supported | [test case](./extensions/type.coffee)
pattern    | supported | [test case](./extensions/type.coffee)
position   | unsupported | TBD
prefix     | supported | [test case](./extensions/module.coffee)
presence   | unsupported | TBD
range      | supported | [test case](./extensions/type.coffee)
reference  | supported | meta data only
refine     | supported | [test case](./extensions/grouping.coffee)
require-instance | supported | [test case](./extensions/type.coffee)
revision      | supported | meta data only
revision-date | supported | meta data only
rpc       | supported | [test case](./extensions/rpc.coffee)
status    | supported | meta data only
submodule | supported | [test case](./extensions/module.coffee)
type      | supported | [test case](./extensions/type.coffee)
typedef   | supported | [test case](./extensions/type.coffee)
unique    | supported | [test case](./extensions/list.coffee)
units     | supported | [test case](./extensions/leaf.coffee)
uses      | supported | [test case](./extensions/grouping.coffee)
value     | supported | [test case](./extensions/type.coffee)
when      | unsupported | TBD
yang-version | supported | differentiates 1.0 and 1.1
yin-element  | supported | internal extension implementation

### Built-in Types

type | status | notes
--- | --- | ---
binary      | unsupported | TBD
bits        | unsupported | TBD
boolean     | supported | [test case](./extensions/type.coffee)
decimal64   | supported | [test case](./extensions/type.coffee)
empty       | supported | [test case](./extensions/type.coffee)
enumeration | supported | [test case](./extensions/type.coffee)
identityref | unsupported | does not enforce
leafref     | supported | [test case](./extensions/type.coffee)
int8   | supported | [test case](./extensions/type.coffee)
int16  | supported | [test case](./extensions/type.coffee)
int32  | supported | [test case](./extensions/type.coffee)
int64  | supported | [test case](./extensions/type.coffee)
uint8  | supported | [test case](./extensions/type.coffee)
uint16 | supported | [test case](./extensions/type.coffee)
uint32 | supported | [test case](./extensions/type.coffee)
number | supported | [test case](./extensions/type.coffee)
string | supported | [test case](./extensions/type.coffee)
union  | supported | [test case](./extensions/type.coffee)
instance-identifier | supported | [test case](./extensions/type.coffee)
