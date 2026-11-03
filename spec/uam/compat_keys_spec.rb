# uam: as chaves Redis precisam ser as da fazer.ai (v4.19.0-fazer-ai.141). Uma troca de imagem
# no meio do stream continua do cursor onde parou só se os nomes forem idênticos. Os literais
# foram lidos na tag; o teste não compara o código da fazer.ai com ele mesmo.
require 'rails_helper'

describe Whatsapp::Connector::Consumer do
  it { expect(described_class.shard_key(3)).to eq('wa:events:3') }
  it { expect(described_class.lease_key(3)).to eq('wa:events:3:lease') }
  it { expect(described_class.topology_key).to eq('wa:consumers:topology') }
  it { expect(described_class.cursor_key('s1')).to eq('wa:cursor:s1') }
  it { expect(described_class.consumer_key('k1')).to eq('wa:consumer:k1') }
  it { expect(described_class.dlq_key).to eq('wa:dlq:events') }
  it { expect(Whatsapp::Connector.key('consumers')).to eq('wa:consumers') }
  it { expect(described_class::GROUP).to eq('chatwoot') }
  it { expect(Whatsapp::Session::PROVIDERS).to eq(%w[native]) }
end
