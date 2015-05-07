
class TableInfo
  addColumn: (name, type, opts) ->

  addIndex: (names...) ->

  addReference: (model) ->

module.exports =
class Migration
  @tables = new Map

  @createTable: (tableName, callback) ->
    tableInfo = new TableInfo
    callback(tableInfo)
    @tables.set tableName, tableInfo
