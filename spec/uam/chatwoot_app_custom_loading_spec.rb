# uam: custom/ é carregado e aplicado pelos ganchos do oficial, sem enterprise/.
require 'rails_helper'

describe ChatwootApp do
  it 'aplica Custom::Channel::Whatsapp no canal' do
    expect(Channel::Whatsapp.ancestors).to include(Custom::Channel::Whatsapp)
  end

  it { is_expected.not_to be_enterprise }
  it { is_expected.to be_custom }
end
