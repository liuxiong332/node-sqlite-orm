_ = require 'underscore'

class TableInfo
  constructor: (@tableName) ->
    @attributes = {}
    @references = {}

  addColumn: (name, type, opts) ->
    @attributes[name] = if opts then _.extend({type}, opts) else {type}
    @primaryKeyName = name if opts?.primaryKey

  addIndex: (names...) ->
    @attributes[name].index = true for name in names

  addReference: (name, tableName, opts={}) ->
    unless (opts = @attributes[name])?
      opts = @attributes[name] = {type: 'INTEGER'}
    opts.references = _.extend {name: tableName}, opts
    @references[name] = opts

  _finishConfig: ->
    for name, opts of @references
      opts.fields ?= Migration.tables[tableName].primaryKeyName

module.exports =
class Migration
  @tables = {}

  @createTable: (tableName, callback) ->
    tableInfo = new TableInfo(tableName)
    callback(tableInfo)
    @tables[tableName] = tableInfo

  @_finishConfig: ->
    for name, info of @tables
      info._finishConfig()
