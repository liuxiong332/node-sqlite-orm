_ = require 'underscore'

class TableInfo
  constructor: (@tableName, opts) ->
    @attributes = {}
    @references = {}
    @indexes = {}

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

  createIndex: (indexName, column) ->
    @indexes[indexName] = column

  _checkPrimaryKey: ->
    @addColumn('id', 'INTEGER', primaryKey: true) unless @primaryKeyName

  _finishConfig: ->
    for name, {references} of @references
      references.fields ?= Migration.tables[references.name].primaryKeyName

module.exports =
class Migration
  @tables = {}

  @createTable: (tableName, opts={}, callback) ->
    if _.isFunction(opts)
      callback = opts
      opts = {}
    tableInfo = new TableInfo(tableName, opts)
    callback?(tableInfo)
    @tables[tableName] = tableInfo

  @_finishConfig: ->
    info._checkPrimaryKey() for name, info of @tables
    info._finishConfig() for name, info of @tables

  @clear: -> @tables = {}
