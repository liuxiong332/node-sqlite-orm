_ = require 'underscore'

class TableInfo
  constructor: (@tableName) ->
    @attributes = {}

  addColumn: (name, type, opts) ->
    @attributes[name] = if opts then _.extend({type}, opts) else {type}

  addIndex: (names...) ->
    @attributes[name].index = true for name in names

  addReference: (model) ->


module.exports =
class Migration
  @tables = {}

  @createTable: (tableName, callback) ->
    tableInfo = new TableInfo(tableName)
    callback(tableInfo)
    @tables[tableName] = tableInfo
