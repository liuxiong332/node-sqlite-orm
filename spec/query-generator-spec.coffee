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
    opts = column1: {$or: {$gt: 5, $lt: 10}, $gt: 8}
    QueryGenerator.expr(opts).should.match '((column1 > 5 OR column1 < 10) AND column1 > 8)'

  it 'updateStmt', ->
    res = QueryGenerator.updateStmt 'table1', {f1: 'h1', f2: 'h2'}, {col1: 'hello'}
    res.should.equal 'UPDATE table1 SET f1 = "h1", f2 = "h2" WHERE col1 = "hello"'

  it 'selectStmt', ->
    opts =
      fields: ['col1', 'col2']
    res = QueryGenerator.selectStmt 'Name', {col: 'hello'}, opts
    res.should.equal 'SELECT col1, col2 FROM Name WHERE col = "hello"'

    opts =
      orderBy: {field: 'col1', asc: true}, limit: 3
    res = QueryGenerator.selectStmt 'Name', null, opts
    res.should.equal 'SELECT * FROM Name ORDER BY col1 ASC LIMIT 3'
