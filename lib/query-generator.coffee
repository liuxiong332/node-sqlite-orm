_ = require 'underscore'

module.exports =
class QueryGenerator
  @createTableStmt: (tableName, attributes) ->
    columnDefs = for colName, opts of attributes
      @columnDef(colName, opts)
    "CREATE TABLE IF NOT EXISTS #{tableName} (#{columnDefs})"

  @columnDef: (name, opts) ->
    return "#{name} #{opts}" if _.isString(opts)
    template = "#{name} #{opts.type}"

    if opts.primaryKey is true
      template += ' PRIMARY KEY'
      template += ' AUTOINCREMENT' if opts.autoIncrement

    if opts.notNull is true
      template += ' NOT NULL'

    if opts.unique is true
      template += ' UNIQUE'

    if opts.default?
      template += " DEFAULT #{opts.default}"

    if (refs = opts.references)?
      columns = refs.fields
      if Array.isArray(columns) then columns = columns.join(',')
      template += " REFERENCES #{refs.name} (#{columns})"
      if opts.onDelete
        template += " ON DELETE #{opts.onDelete.toUpperCase()}"
      if opts.onUpdate
        template += " ON UPDATE #{opts.onUpdate.toUpperCase()}"
    template

  @insertStmt: (tableName, fields) ->
    keys = []
    values = []
    for key, value of fields
      keys.push key
      values.push @wrapValue(value)
    "INSERT INTO #{tableName} (#{keys.join(',')}) VALUES (#{values.join(',')})"

  @updateStmt: (tableName, fields, whereOpts) ->
    values = for key, value of fields
      "#{key} = #{@wrapValue(value)}"
    sql = "UPDATE #{tableName} SET #{values.join(', ')}"
    if whereOpts
      whereOpts = whereOpts.where if whereOpts.where?
      sql += " WHERE #{@expr(whereOpts)}"
    sql

  @removeStmt: (tableName, whereOpts) ->
    if whereOpts
      whereOpts = whereOpts.where if whereOpts.where?
      "DELETE FROM #{tableName} WHERE #{@expr(whereOpts)}"
    else
      "DELETE FROM #{tableName}"

  @orderingTerm: (orderBy) ->
    if _.isString(orderBy) then orderByFields = orderBy
    else if Array.isArray(orderBy)
      orderByFields = orderBy.join(', ')
    else
      orderByFields = orderBy.field ? orderBy.fields.join(', ')
    template = "ORDER BY #{orderByFields}"
    if orderBy.asc
      template += " ASC"
    else if orderBy.desc
      template += " DESC"
    template

  @selectStmt: (tableName, where, opts={}) ->
    columns = opts.field ? opts.fields?.join(', ') ? '*'
    template = "SELECT #{columns} FROM #{tableName}"
    if where then template += " WHERE #{@expr(where)}"
    if opts.orderBy then template += " #{@orderingTerm(opts.orderBy)}"
    if opts.limit
      template += " LIMIT #{opts.limit}"
    template

  @createIndexStmt: (tableName, indexName, columns) ->
    columns = columns.join(', ')
    "CREATE INDEX IF NOT EXISTS #{indexName} ON #{tableName} (#{columns})"

  @dropTableStmt: (tableName) ->
    "DROP TABLE IF EXISTS #{tableName}"

  COMPARATOR_MAP =
    $eq: '=', $ne: '!=', $gte: '>=', $gt: '>', $lte: '<=', $lt: '<'
    $not: 'IS NOT', $is: 'IS', $like: 'LIKE', $notLike: 'NOT LIKE'

  LOGICAL_MAP =
    $and: 'AND', $or: 'OR'

  exprStmtsJoin = (stmts, sep) ->
    isParenthesis = stmts.length > 1
    stmts = stmts.join(sep)
    stmts = "(#{stmts})" if isParenthesis
    stmts

  @valueListStr: (values) ->
    (@wrapValue(val) for val in values).join(', ')

  @oneExpr: (key, value) ->
    if key in ['$and', '$or']
      resArr = (@oneExpr(subKey, subVal) for subKey, subVal of value)
      exprStmtsJoin(resArr, " #{LOGICAL_MAP[key]} ")
    else if key is '$not'
      resArr = (@oneExpr(subKey, subVal) for subKey, subVal of value)
      "NOT #{exprStmtsJoin(resArr, " AND ")}"
    else if not _.isObject(value)
      "#{key} = #{@wrapValue(value)}"
    else
      resStrs = for subKey, subVal of value
        if subKey in ['$and', '$or']
          resArr = for nextKey, nextVal of subVal
            @oneExpr(key, "#{nextKey}": nextVal)
          exprStmtsJoin(resArr, " #{LOGICAL_MAP[subKey]} ")
        else if subKey is '$not'
          resArr = for nextKey, nextVal of subVal
            @oneExpr(key, "#{nextKey}": nextVal)
          "NOT #{exprStmtsJoin(resArr, " AND ")}"
        else if subKey is '$in'
          "#{key} IN (#{@valueListStr(subVal)})"
        else if subKey is '$notIn'
          "#{key} NOT IN (#{@valueListStr(subVal)})"
        else if subKey is '$between'
          "#{key} BETWEEN #{subVal.join(' AND ')}"
        else if subKey is '$notBetween'
          "#{key} NOT BETWEEN #{subVal.join(' AND ')}"
        else if COMPARATOR_MAP[subKey]
          subVal = if subVal is null then 'NULL' else @wrapValue(subVal)
          "#{key} #{COMPARATOR_MAP[subKey]} #{subVal}"
      exprStmtsJoin(resStrs, ' AND ')

  @expr: (opts) ->
    resStrs = (@oneExpr(key, value) for key, value of opts)
    resStrs.join(' AND ')

  @wrapValue: (val) ->
    unless val? then 'NULL'
    else if _.isString(val) then "\"#{val}\""
    else val
