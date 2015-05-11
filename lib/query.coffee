Q = require 'q'
QueryGenerator = require './query-generator'

module.exports =
class Query
  constructor: (@db) ->

  createTable: (tableName, attrs) ->
    defer = Q.defer()
    @db.run QueryGenerator.createTableStmt(tableName, attrs), (err) ->
      if err then defer.reject(err) else defer.resolve(this.lastID)
    defer.promise

  insert: (tableName, fields) ->
    Q.ninvoke @db, 'run', QueryGenerator.insertStmt(tableName, fields)

  update: (tableName, fields, where) ->
    Q.ninvoke @db, 'run', QueryGenerator.updateStmt(tableName, fields, where)
