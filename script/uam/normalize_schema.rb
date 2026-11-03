# frozen_string_literal: true

# uam: deixa o db/schema.rb igual ao do oficial mais só as linhas que o fork acrescenta.
#
#   ruby script/uam/normalize_schema.rb <schema_oficial> <schema_dump>  > db/schema.rb
#
# O dump do Postgres reordena índices e reescreve cláusulas `where` de tabelas que o fork não
# toca; isso só gera conflito no merge mensal. Aqui cada bloco `create_table` do oficial fica
# como está, as linhas novas de coluna entram depois da última coluna do bloco, os índices
# novos depois do último índice, as tabelas novas e as foreign keys novas na ordem do dump.
# O cabeçalho `Schema[x.y]` vem do dump.

def blocks(text)
  out = {}
  text.scan(/^  create_table "([^"]+)".*?\n  end\n/m) { out[Regexp.last_match(1)] = Regexp.last_match(0) }
  out
end

official, dump = ARGV.map { |f| File.read(f) }
abort 'uso: normalize_schema.rb <oficial> <dump>' unless official && dump

ob = blocks(official)
db = blocks(dump)
result = official.sub(/ActiveRecord::Schema\[[\d.]+\]/, dump[/ActiveRecord::Schema\[[\d.]+\]/])

ob.each do |name, oblock|
  dblock = db[name] or abort "tabela #{name} sumiu do dump"
  olines = oblock.lines
  new_lines = dblock.lines - olines
  dropped = olines - dblock.lines
  # linhas que só mudaram de forma (mesmo nome de índice) não contam como novas
  new_lines.reject! { |l| (n = l[/name: "([^"]+)"/, 1]) && dropped.any? { |d| d.include?(%(name: "#{n}")) } }
  next if new_lines.empty?

  cols, idxs = new_lines.partition { |l| !l.start_with?('    t.index') }
  lines = olines.dup
  last_col = lines.rindex { |l| l.start_with?('    t.') && !l.start_with?('    t.index') }
  lines.insert(last_col + 1, *cols)
  last_idx = lines.rindex { |l| l.start_with?('    t.index') } || (last_col + cols.size)
  lines.insert(last_idx + 1, *idxs)
  result = result.sub(oblock, lines.join)
end

(db.keys - ob.keys).each do |name|
  following = ob.keys.sort.find { |k| k > name }
  anchor = following ? ob[following] : nil
  abort "sem âncora para #{name}" unless anchor
  result = result.sub(anchor, "#{db[name]}\n#{anchor}")
end

ofks = official.lines.grep(/^  add_foreign_key /)
(dump.lines.grep(/^  add_foreign_key /) - ofks).each do |fk|
  after = ofks.select { |l| l < fk }.last
  result = after ? result.sub(after, "#{after}#{fk}") : result
end

print result
