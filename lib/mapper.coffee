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

module.exports =
class Mapper
  constructor: (@fileName) ->
    @db = null

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
      createPromises = for tableName, tableInfo of Migration.tables
        # extend the model class's attributes
        ModelBase.models[tableName]?.extendModel this, tableInfo
        # create the database table
        @query.createTable(tableName, tableInfo.attributes)
      Q.all(createPromises)

  close: ->
    Q.ninvoke @db, 'close'

  getQuery: -> @query

  @INTEGER = 'INTEGER'
  @REAL = 'REAL'
  @TEXT = 'TEXT'
  @BLOB = 'BLOB'
