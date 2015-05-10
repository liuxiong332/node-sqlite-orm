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
