# uam: a caixa native não tem a janela de 24 h da Cloud API (Custom::Conversations::MessageWindowService).
require 'rails_helper'

describe Conversations::MessageWindowService do
  def conversation_on(provider)
    channel = create(:channel_whatsapp, provider: provider, sync_templates: false, validate_provider_config: false)
    conversation = create(:conversation, inbox: channel.inbox, account: channel.account)
    create(:message, conversation: conversation, account: channel.account, inbox: channel.inbox,
                     message_type: :incoming, created_at: 2.days.ago)
    conversation
  end

  it 'deixa responder na caixa native fora das 24 h' do
    expect(described_class.new(conversation_on('native')).can_reply?).to be(true)
  end

  it 'mantém a janela de 24 h na Cloud API' do
    expect(described_class.new(conversation_on('whatsapp_cloud')).can_reply?).to be(false)
  end
end
