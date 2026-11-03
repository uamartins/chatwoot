# uam: trechos do native no canal WhatsApp (Custom::Channel::Whatsapp + ChannelExtension).
require 'rails_helper'

describe Channel::Whatsapp do
  let(:native) { create(:channel_whatsapp, provider: 'native', sync_templates: false, validate_provider_config: false) }

  it { expect(described_class::PROVIDERS).to eq(%w[default whatsapp_cloud native]) }

  it 'põe a extensão da sessão acima do módulo custom, como na fazer.ai' do
    ancestors = described_class.ancestors
    expect(ancestors.index(Whatsapp::Session::ChannelExtension)).to be < ancestors.index(Custom::Channel::Whatsapp)
  end

  it 'lê uma caixa de provedor que o fork não traz sem tratá-la como sessão' do
    channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    channel.update_column(:provider, 'baileys') # rubocop:disable Rails/SkipsModelValidations
    reloaded = described_class.find(channel.id)
    expect(reloaded.provider).to eq('baileys')
    expect(reloaded.session_provider?).to be(false)
  end

  it 'grava o estado da conexão normalizado e ignora o mesmo estado' do
    native.update_provider_connection!(connection: 'open', qr_data_url: nil)
    expect(native.reload.provider_connection).to eq('connection' => 'open', 'qr_data_url' => nil)
    expect { native.update_provider_connection!('connection' => 'open', 'qr_data_url' => nil) }.not_to(change { native.reload.updated_at })
  end

  it 'separa o que o agente vê do que só o admin vê' do
    native.update_provider_connection!('connection' => 'connecting', 'qr_data_url' => 'data:x', 'error' => 'e')
    expect(native.provider_connection_agent_data).to eq(connection: 'connecting')
    expect(native.provider_connection_admin_data).to eq(qr_data_url: 'data:x', error: 'e')
  end

  it 'manda o recibo de leitura pelo provedor e respeita mark_as_read' do
    conversation = create(:conversation, inbox: native.inbox)
    service = native.provider_service
    allow(native).to receive(:provider_service).and_return(service)
    allow(service).to receive(:read_messages)
    native.read_messages([], conversation: conversation)
    expect(service).to have_received(:read_messages)

    native.provider_config = native.provider_config.merge('mark_as_read' => false)
    native.read_messages([], conversation: conversation)
    expect(service).to have_received(:read_messages).once
  end
end
