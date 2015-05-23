Q = require 'q'
QueryGenerator = require './query-generator'

module.exports =
class Query
  constructor: (@db) ->

  createTable: (tableName, attrs) ->
    Q.ninvoke @db, 'run', QueryGenerator.createTableStmt(tableName, attrs)

  insert: (tableName, fields) ->
    defer = Q.defer()
    @db.run QueryGenerator.insertStmt(tableName, fields), (err) ->
      if err then defer.reject(err) else defer.resolve(this.lastID)
    defer.promise

  update: (tableName, fields, where) ->
    Q.ninvoke @db, 'run', QueryGenerator.updateStmt(tableName, fields, where)

  select: (tableName, where, opts) ->
    Q.ninvoke @db, 'all', QueryGenerator.selectStmt(tableName, where, opts)

  selectEach: (tableName, where, opts, stepFunc) ->
    sql = QueryGenerator.selectStmt(tableName, where, opts)
    Q.ninvoke @db, 'each', sql, stepFunc

  selectOne: (tableName, where, opts) ->
    Q.ninvoke @db, 'get', QueryGenerator.selectStmt(tableName, where, opts)

  remove: (tableName, where) ->
    Q.ninvoke @db, 'run', QueryGenerator.removeStmt(tableName, where)

  createIndex: (tableName, indexName, columns) ->
    sql = QueryGenerator.createIndexStmt(tableName, indexName, columns)
    Q.ninvoke @db, 'run', sql

  dropTable: (tableName) ->
    Q.ninvoke @db, 'run', QueryGenerator.dropTableStmt(tableName)

  beginTransaction: -> Q.ninvoke @db, 'run', 'BEGIN TRANSACTION'
  endTransaction: -> Q.ninvoke @db, 'run', 'END TRANSACTION'
