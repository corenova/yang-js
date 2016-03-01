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

### Language Extensions

extension | behavior | status
--- | --- | ---
anyxml | TBD | unsupported
augment | schema merge | supported
base | TBD | supported
belongs-to | define prefix | supported
bit | TBD | unsupported
case | TBD | unsupported
choice | TBD | unsupported
config | property meta | supported
contact | meta data | supported
container | synth.Object | supported
default | property meta | supported
description | meta data | supported
deviate | merge/alter | unsupported
deviation | merge/alter | unsupported
enum | property meta | supported
error-app-tag | TBD | unsupported
error-message | TBD | unsupported
feature | module meta | supported
fraction-digits | TBD | unsupported
grouping | define/export | supported
identity | module meta | supported
if-feature | conditional | supported
import | preprocess | supported
include | preprocess | supported
input | rpc schema | supported
key | property meta | supported
leaf | synth.Property | supported
leaf-list | synth.List | supported
length | property meta | supported
list | synth.List | supported
mandatory | property meta | supported
max-elements | property meta | supported
min-elements | property meta | supported
module | synth.Store | supported
must | conditional | unsupported
namespace | module meta | supported
notification | TBD | unsupported
ordered-by | property meta | unsupported
organization | module meta | supported
output | rpc schema | supported
path | tree traversal | supported (relative nodes)
pattern | regexp | supported
position | TBD | unsupported
prefix | module meta | supported
presence | meta data | unsupported
range | property meta | supported
reference | meta data | supported
refine | merge | supported
require-instance | relationship prop meta | supported
revision | meta data | supported
revision-date | conditional | supported
rpc | synth.Action | supported
status | meta data | supported
submodule | preprocess | supported
type | property meta | supported
typedef | type meta | supported
unique | property meta | supported
units | property meta | supported
uses | schema merge | supported
value | property meta | supported
when | conditional | unsupported
yang-version | module meta | supported
yin-element | TBD | unsupported

### Built-in Types

type | behavior | status
--- | --- | ---
binary | as-is | partial
bits | TBD | unsupported
boolean | Boolean | supported
decimal64 | as-is | partial
empty | flag | partial
enumeration | mapping | supported
identityref | enforced | supported
leafref | resolved | supported
int8 | constraint | supported
int16 | constraint | supported
int32 | constraint | supported
int64 | constraint | supported
uint8 | constraint | supported
uint16 | constraint | supported
uint32 | constraint | supported
number* | constraint | new (doesn't exist in RFC 6020)
string | constraint | supported
union | selective | supported
instance-identifier | TBD | partial
