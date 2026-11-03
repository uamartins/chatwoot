# uam: trechos do native no contact_inbox (Custom::ContactInbox).
require 'rails_helper'

describe ContactInbox do
  let(:contact_inbox) { create(:contact_inbox) }

  it 'marca e desmarca a saída do grupo' do
    contact_inbox.mark_group_left!
    expect(contact_inbox.reload).to be_group_left
    contact_inbox.mark_group_rejoined!
    expect(contact_inbox.reload).not_to be_group_left
  end

  it 'limpa a marca de número sem WhatsApp' do
    contact_inbox.update!(whatsapp_missing_checked_at: Time.current)
    contact_inbox.clear_whatsapp_missing!
    expect(contact_inbox.reload.whatsapp_missing_checked_at).to be_nil
  end

  it 'aceita os ids do native: LID e grupo com até 20 dígitos' do
    inbox = create(:channel_whatsapp, provider: 'native', sync_templates: false, validate_provider_config: false).inbox
    %w[12345678901234567890 120363012345678901-1700000000].each do |source_id|
      expect(build(:contact_inbox, inbox: inbox, contact: create(:contact, account: inbox.account), source_id: source_id)).to be_valid
    end
  end
end
