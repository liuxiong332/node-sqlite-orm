queryGenerator = require '../lib/query-generator'
Mapper = require '../lib/mapper'
path = require 'path'

describe 'query generator', ->
  db = null

  beforeEach (done) ->
    dbPath = path.resolve(__dirname, 'temp/test.db')
    new Mapper(dbPath).getDB()
    .then (_db) ->
      db = _db
      done()
    .catch (err) -> done(err)

  # afterEach (done) ->
  #   db.close(done)

  it 'createTableStmt', (done) ->
    attr =
      type: 'INT', primaryKey: true, notNull: true, unique: true

    db.serialize ->
      db.run queryGenerator.createTableStmt 'fakeTable', {column1: attr}

    db.close -> done()
