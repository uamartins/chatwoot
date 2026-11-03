# uam: envio pela sessão do WhatsApp (native) que falha termina failed com o motivo, ou volta
# para o retry do SendReplyJob quando pode dar certo (Custom::Whatsapp::SendOnWhatsappService,
# Custom::SendReplyJob).
require 'rails_helper'

describe Whatsapp::SendOnWhatsappService do
  let(:channel) { create(:channel_whatsapp, provider: 'native', sync_templates: false, validate_provider_config: false) }
  let(:contact) { create(:contact, account: channel.account, phone_number: '+5541999990000') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '5541999990000') }
  let(:conversation) { create(:conversation, inbox: channel.inbox, account: channel.account, contact: contact, contact_inbox: contact_inbox) }
  let(:message) { create(:message, conversation: conversation, account: channel.account, inbox: channel.inbox, message_type: :outgoing, content: 'oi') }

  it 'grava o source_id que a sessão devolveu' do
    allow_any_instance_of(Whatsapp::Session::Facade).to receive(:send_message).and_return('WAID1') # rubocop:disable RSpec/AnyInstance
    described_class.new(message: message).perform
    expect(message.reload.source_id).to eq('WAID1')
  end

  it 'marca failed com o motivo um erro que não se repete' do
    allow_any_instance_of(Whatsapp::Session::Facade).to receive(:send_message) # rubocop:disable RSpec/AnyInstance
      .and_raise(Whatsapp::Session::Errors::InvalidPayload, 'payload recusado')
    described_class.new(message: message).perform
    expect(message.reload.status).to eq('failed')
    expect(message.external_error).to be_present
  end

  it 'devolve ao retry do SendReplyJob um erro que pode dar certo' do
    allow_any_instance_of(Whatsapp::Session::Facade).to receive(:send_message) # rubocop:disable RSpec/AnyInstance
      .and_raise(Whatsapp::Session::Errors::RateLimited, 'devagar')
    expect { described_class.new(message: message).perform }.to raise_error(Whatsapp::Session::Errors::RateLimited)
    expect(message.reload.status).not_to eq('failed')
  end

  it 'marca failed quando o SendReplyJob esgota as tentativas' do
    SendReplyJob.fail_message(message.id, 'esgotou')
    expect(message.reload.status).to eq('failed')
  end
end
