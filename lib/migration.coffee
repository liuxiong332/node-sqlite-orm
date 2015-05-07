_ = require 'underscore'

class TableInfo
  constructor: (@tableName) ->
    @attributes = {}

  addColumn: (name, type, opts) ->
    opts = if opts then _.extend({type}, opts) else {type}
    @attributes[name] = _.extend {type}, opts

  addIndex: (names...) ->
    @attributes[name].index = true for name in names

  addReference: (model) ->


module.exports =
class Migration
  @tables = new Map

  @createTable: (tableName, callback) ->
    tableInfo = new TableInfo
    callback(tableInfo)
    @tables.set tableName, tableInfo
