
QueryGenerator = require './query-generator'

module.exports =
class Query
  constructor: (@db) ->

  createTable: (tableName, attrs) ->
    @db.run QueryGenerator.createTableStmt(tableName, attrs)
