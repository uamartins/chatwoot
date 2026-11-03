# uam: trechos do native na conversa (Custom::Conversation).
require 'rails_helper'

describe Conversation do
  let(:conversation) { create(:conversation) }

  it 'tem o tipo de grupo' do
    conversation.update!(group_type: :group)
    expect(conversation.reload).to be_group_type_group
  end

  it 'leva os metadados do broadcast no evento de conversa atualizada' do
    allow(Rails.configuration.dispatcher).to receive(:dispatch)
    conversation.dispatch_conversation_updated_event(broadcast_metadata: { source: 'whatsapp_missing' })
    expect(Rails.configuration.dispatcher).to have_received(:dispatch)
      .with(Events::Types::CONVERSATION_UPDATED, anything, hash_including(broadcast_metadata: { source: 'whatsapp_missing' }))
  end
end
