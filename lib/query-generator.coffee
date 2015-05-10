
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

    if (refs = opts.references)?
      columns = refs.field ? refs.fields.join(',')
      template += " REFERENCES #{refs.name} (#{columns})"
      if opts.onDelete
        template += " ON DELETE #{opts.onDelete.toUpperCase()}"
      if opts.onUpdate
        template += " ON UPDATE #{opts.onUpdate.toUpperCase()}"
    template
