# uam: chave por conta do native (Custom::Account).
require 'rails_helper'

describe Account do
  let(:account) { create(:account) }

  it 'oferece o native a toda conta e o tira de uma pela chave' do
    expect(account.whatsapp_session_provider_enabled?('native')).to be(true)
    account.update!(whatsapp_native_disabled: '1')
    expect(account.reload.whatsapp_session_provider_enabled?('native')).to be(false)
  end

  it { expect(account.whatsapp_session_provider_enabled?('uazapi')).to be(false) }
end
