global.Yang = require '..'

describe "YANG 1.0 (RFC-6020) Compliance:", ->

  describe 'leaf',      -> require './extension/leaf'
  describe 'leaf-list', -> require './extension/leaf-list'
  describe 'container', -> require './extension/container'
  describe 'list',      -> require './extension/list'
  describe 'type',      -> require './extension/type'
  describe 'rpc',       -> require './extension/rpc'
  describe 'grouping',  -> require './extension/grouping'
  describe 'extension', -> require './extension/extension'
  describe 'module',    -> require './extension/module'

describe "YANG 1.1 (DRAFT) Compliance:", ->

  describe 'action',   -> it.skip "todo"
  describe 'anydata',  -> it.skip "todo"
  describe 'modifier', -> it.skip "todo"
