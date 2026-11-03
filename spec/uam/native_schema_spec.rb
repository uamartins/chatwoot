# uam: as colunas, a tabela e os índices das migrations do native (timestamps da fazer.ai).
require 'rails_helper'

describe ActiveRecord::Schema do
  let(:conn) { ActiveRecord::Base.connection }

  {
    'channel_whatsapp' => %w[provider_connection],
    'contacts' => %w[group_type],
    'conversations' => %w[group_type],
    'contact_inboxes' => %w[group_left_at whatsapp_missing_checked_at]
  }.each do |table, cols|
    it "#{table} tem #{cols.join(', ')}" do
      expect(conn.columns(table).map(&:name)).to include(*cols)
    end
  end

  it 'tem a tabela group_members' do
    expect(conn.table_exists?('group_members')).to be(true)
  end

  it 'tem o índice único do session_id' do
    expect(conn.index_name_exists?('channel_whatsapp', 'index_channel_whatsapp_session_id')).to be(true)
  end
end
