global.yang = require '..'

describe "YANG 1.0 (RFC-6020) Compliance:", ->

  describe 'leaf',      -> require './extensions/leaf'
  describe 'leaf-list', -> require './extensions/leaf-list'
  describe 'container', -> require './extensions/container'
  describe 'list',      -> require './extensions/list'
  describe 'type',      -> require './extensions/type'
  describe 'rpc',       -> require './extensions/rpc'
  describe 'grouping',  -> require './extensions/grouping'
  describe 'module',    -> require './extensions/module'
  describe 'import',    -> require './extensions/import'
  describe 'extension', -> require './extensions/extension'

describe "YANG 1.1 (DRAFT) Compliance:", ->

  describe 'action',   -> it.skip "todo"
  describe 'anydata',  -> it.skip "todo"
  describe 'modifier', -> it.skip "todo"
