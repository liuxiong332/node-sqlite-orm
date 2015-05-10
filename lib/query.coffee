Q = require 'q'
QueryGenerator = require './query-generator'

module.exports =
class Query
  constructor: (@db) ->

  createTable: (tableName, attrs) ->
    Q.ninvoke @db, 'run', QueryGenerator.createTableStmt(tableName, attrs)

  insert: (tableName, fields) ->
    Q.ninvoke @db, 'run', QueryGenerator.insertStmt(tableName, fields)
