# uam: configuração que o native precisa fora do núcleo.
require 'rails_helper'

describe ImportGuards do
  it 'reserva no pool uma conexão por shard do consumer' do
    expect(ActiveRecord::Base.connection_pool.size).to be >= 5 + 16
  end

  it 'traz os textos do native' do
    expect(I18n.t('errors.whatsapp.group_announcement_only', locale: :pt_BR)).not_to include('translation missing')
  end

  it 'cala o SyncDispatcher durante a importação' do
    expect(SyncDispatcher.ancestors).to include(ImportGuards::SilentSyncDispatch)
  end
end
