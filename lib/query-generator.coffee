_ = require 'underscore'

module.exports =
class QueryGenerator
  @createTableStmt: (tableName, attributes) ->
    columnDefs = for colName, opts of attributes
      @columnDef(colName, opts)
    "CREATE TABLE IF NOT EXISTS #{tableName} (#{columnDefs})"

  @columnDef: (name, opts) ->
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
      columns = refs.field ? refs.fields.join(',')
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
      values.push value
    "INSERT INTO #{tableName} (#{keys.join(',')}) VALUES (#{values.join(',')})"

  COMPARATOR_MAP =
    $eq: '=', $ne: '!=', $gte: '>=', $gt: '>', $lte: '<=', $lt: '<'
    $not: 'IS NOT', $is: 'IS', $like: 'LIKE', $notLike: 'NOT LIKE'

  LOGICAL_MAP =
    $and: 'AND', $or: 'OR'

  @oneExpr: (key, value) ->
    if key in ['$and', '$or']
      resArr = (@oneExpr(subKey, subVal) for subKey, subVal of value)
      '(' + resArr.join(" #{LOGICAL_MAP[key]} ") + ')'
    else if key is '$not'
      resArr = (@oneExpr(subKey, subVal) for subKey, subVal of value)
      'NOT (' + resArr.join(" AND ") + ')'
    else if _.isString(value)
      "#{key}=#{value}"
    else
      resStrs = for subKey, subVal of value
        if subKey in ['$and', '$or']
          resArr = for nextKey, nextVal of subVal
            @oneExpr(key, nextKey: nextVal)
          '(' + resArr.join(" #{LOGICAL_MAP[key]} ") + ')'
        else if subKey is '$not'
          resArr = for nextKey, nextVal of subVal
            @oneExpr(key, nextKey: nextVal)
          'NOT (' + resArr.join(" AND ") + ')'
        else if subKey is '$in'
          "#{key} IN (#{subVal.join(', ')})"
        else if subKey is '$notIn'
          "#{key} NOT IN (#{subVal.join(', ')})"
        else if subKey is '$between'
          "#{key} BETWEEN #{subVal.join(' AND ')}"
        else if subKey is '$notBetween'
          "#{key} NOT BETWEEN #{subVal.join(' AND ')}"
        else if COMPARATOR_MAP[subKey]
          if subVal is null then subVal = 'NULL'
          "#{key} #{COMPARATOR_MAP[subKey]} #{subVal}"
      "(#{resStrs.join(' AND ')})"

  @expr: (opts) ->
    for key, value of opts
