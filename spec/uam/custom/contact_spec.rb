# uam: trechos do native no contato (Custom::Concerns::Contact).
require 'rails_helper'

describe Contact do
  it 'tem o tipo de grupo e os membros' do
    group = create(:contact, group_type: :group)
    member = create(:contact, account: group.account)
    GroupMember.create!(group_contact: group, contact: member)
    expect(group).to be_group_type_group
    expect(group.group_memberships.map(&:contact)).to eq([member])
  end

  it 'grava marcas de avatar no additional_attributes sob lock, sem perder o resto' do
    contact = create(:contact, additional_attributes: { 'city' => 'x', 'old' => 1 })
    contact.update_avatar_sync_markers!(remove: ['old'], merge: { 'avatar_synced_at' => 1 })
    expect(contact.reload.additional_attributes).to eq('city' => 'x', 'avatar_synced_at' => 1)
  end
end
