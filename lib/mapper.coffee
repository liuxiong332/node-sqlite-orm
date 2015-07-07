###
 sqlite-orm
 https://github.com/liuxiong332/sqlite-orm

 Copyright (c) 2015 liuxiong
 Licensed under the MIT license.
###
Q = require 'q'
sqlite3 = require('sqlite3').verbose()
_ = require 'underscore'
Migration = require './migration'
Query = require './query'
ModelBase = require './model-base'
Cache = require './cache'

module.exports =
class Mapper
  constructor: (@fileName, opts={}) ->
    @db = null
    @cache = new Cache maxSize: opts.maxCacheSize
    @interpreters = {}
    @initInterpreters()

  getDB: ->
    defer = Q.defer()
    if @db
      defer.resolve(@db)
    else
      @db = new sqlite3.Database @fileName, (err) =>
        if err then defer.reject(err) else defer.resolve(@db)
        @query = new Query(@db)
    defer.promise

  getModel = (tableName) ->
    Model = ModelBase.models[tableName]
    unless Model
      Model = class
        @_name = tableName
        ModelBase.includeInto  this
        constructor: (params) -> @initModel(params)
    Model

  sync: ->
    @getDB().then =>
      Migration._finishConfig()
      createPromises = for tableName, tableInfo of Migration.tables
        # extend the model class's attributes
        getModel(tableName).extendModel this, tableInfo
        # create the database table
        attributes = tableInfo.attributes
        @query.createTable(tableName, attributes, @interpreters).then =>
          promises = for indexName, column of tableInfo.indexes
            @query.createIndex(tableName, indexName, column)
          Q.all promises

      Q.all(createPromises).then ->
        Model.initAssos?() for name, Model of ModelBase.models
        Model.extendAssos() for name, Model of ModelBase.models

  registerDataTypeInterpreter: (dataType, interpreter) ->
    @interpreters[dataType] = interpreter

  getInterpreter: (dataType) -> @interpreters[dataType]

  initInterpreters: ->
    @registerDataTypeInterpreter 'DATETIME',
      from: (val) -> new Date(val)
      to: (val) -> val.getTime()
    @registerDataTypeInterpreter 'BOOL',
      from: (val) -> val isnt 0
      to: (val) -> if val then 1 else 0

  beginTransaction: -> @query.beginTransaction()

  endTransaction: -> @query.endTransaction()

  scopeTransaction: (callback) ->
    @query.beginTransaction()
    .then -> callback()
    .then => @query.endTransaction()

  dropAllTables: ->
    Q.all (model.drop() for name, model of ModelBase.models)

  close: ->
    Q.ninvoke @db, 'close'

  getQuery: -> @query
  @Migration = Migration
  @ModelBase = ModelBase

  @INTEGER = 'INTEGER'
  @REAL = 'REAL'
  @TEXT = 'TEXT'
  @BLOB = 'BLOB'
  @DATETIME = 'DATETIME'
  @BOOL = 'BOOL'
