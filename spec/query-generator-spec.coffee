QueryGenerator = require '../lib/query-generator'

describe 'query generator', ->
  it 'columnDef', ->
    attr =
      type: 'INT', primaryKey: true, notNull: true, unique: true
    stmt = QueryGenerator.columnDef 'Name', attr
    stmt.should.equal 'Name INT PRIMARY KEY NOT NULL UNIQUE'

    # attr =
    #   type: 'INTEGER', references:
    #     fields: ['id', 'name'], onDelete: true, onUpdate: true
    # stmt = QueryGenerator.columnDef 'Name', attr
    # stmt.should.equal 'Name INTEGER REFERENCES '

  it 'expr', ->
    opts = column1: 'hello'
    QueryGenerator.expr(opts).should.equal 'column1 = "hello"'
    opts = {column1: 'hello', column2: 'world'}
    QueryGenerator.expr(opts).should.equal 'column1 = "hello" AND column2 = "world"'
    opts = column1: $gt: 5
    QueryGenerator.expr(opts).should.match /column1 > 5/
    opts = $or: {column1: {$gt: 5}, column2: 'world'}
    QueryGenerator.expr(opts).should.match /column1 > 5 OR column2 = "world"/
    opts = $not: {column1: {$gt: 5}, column2: 'world'}
    QueryGenerator.expr(opts).should.match 'NOT (column1 > 5 AND column2 = "world")'
    opts = column1: {$gt: 5, $lt: 10}
    QueryGenerator.expr(opts).should.match '(column1 > 5 AND column1 < 10)'
    opts = column1: {$or: {$gt: 5, $lt: 10}}
    QueryGenerator.expr(opts).should.match '(column1 > 5 OR column1 < 10)'
