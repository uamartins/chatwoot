# uam: trechos do native na mensagem (Custom::Message).
require 'rails_helper'

describe Message do
  let(:conversation) { create(:conversation) }

  it 'reconhece reação, apagada e reação removida' do
    reaction = create(:message, conversation: conversation, content: '👍', content_attributes: { is_reaction: true })
    expect(reaction).to be_reaction
    expect(reaction).not_to be_deleted
    reaction.update!(content_attributes: reaction.content_attributes.merge('deleted' => true))
    expect(reaction).to be_removed_reaction
  end

  it 'esconde reações removidas e mantém o resto' do
    kept = create(:message, conversation: conversation, content: 'oi')
    removed = create(:message, conversation: conversation, content: '', content_attributes: { is_reaction: true, deleted: true })
    expect(conversation.messages.hide_removed_reactions).to include(kept)
    expect(conversation.messages.hide_removed_reactions).not_to include(removed)
  end

  it 'atualiza sob lock' do
    message = create(:message, conversation: conversation, content: 'oi')
    message.update_under_lock!(content: 'olá')
    expect(message.reload.content).to eq('olá')
  end

  it 'aceita os atributos de conteúdo do native' do
    message = create(:message, conversation: conversation, content: 'oi',
                               content_attributes: { is_edited: true, previous_content: 'oe', pending_source_id: 'x' })
    expect([message.is_edited, message.previous_content, message.pending_source_id]).to eq([true, 'oe', 'x'])
  end
end
