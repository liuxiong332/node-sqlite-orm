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

  getDB: ->
    defer = Q.defer()
    if @db
      defer.resolve(@db)
    else
      @db = new sqlite3.Database @fileName, (err) =>
        if err then defer.reject(err) else defer.resolve(@db)
        @query = new Query(@db)
    defer.promise

  sync: ->
    @getDB().then =>
      Migration._finishConfig()
      createPromises = for tableName, tableInfo of Migration.tables
        # extend the model class's attributes
        ModelBase.models[tableName]?.extendModel this, tableInfo
        # create the database table
        @query.createTable(tableName, tableInfo.attributes).then =>
          promises = for indexName, column of tableInfo.indexes
            @query.createIndex(tableName, indexName, column)
          Q.all promises

      Q.all(createPromises).then ->
        Model.initAssos?() for name, Model of ModelBase.models
        Model.extendAssos() for name, Model of ModelBase.models

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
