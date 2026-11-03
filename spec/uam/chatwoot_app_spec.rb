# uam: as extensões aplicadas dependem só das pastas que existem na imagem.
require 'rails_helper'

describe ChatwootApp do
  it 'aplica só custom quando enterprise/ não existe' do
    allow(described_class).to receive_messages(enterprise?: false, custom?: true)
    expect(described_class.extensions).to eq(%w[custom])
  end

  it 'mantém a ordem do oficial com as duas' do
    allow(described_class).to receive_messages(enterprise?: true, custom?: true)
    expect(described_class.extensions).to eq(%w[enterprise custom])
  end

  it 'não aplica nada sem as duas' do
    allow(described_class).to receive_messages(enterprise?: false, custom?: false)
    expect(described_class.extensions).to eq([])
  end
end
