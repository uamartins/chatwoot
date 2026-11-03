# frozen_string_literal: true

# uam: exemplos das specs portadas da fazer.ai que dependem de algo que o fork não traz
# (provedores uazapi/Baileys/Z-API, a Cloud com typing da fazer.ai, recursos fora da F2).
# Eles ficam no arquivo, idênticos à tag, e aparecem como pendentes com o motivo, em vez de
# serem apagados. A lista e os motivos estão em spec/uam/excluded_examples.yml, por arquivo e
# descrição completa do exemplo.
module UamExcludedExamples
  LIST = Rails.root.join('spec/uam/excluded_examples.yml')

  def self.reasons
    @reasons ||= (YAML.safe_load_file(LIST) || {}).transform_values do |examples|
      examples.to_h { |e| [e.fetch('example'), e.fetch('reason')] }
    end
  end

  def self.reason_for(metadata)
    file = metadata[:rerun_file_path].to_s.delete_prefix('./')
    reasons.dig(file, metadata[:full_description])
  end
end

RSpec.configure do |config|
  config.define_derived_metadata do |metadata|
    reason = UamExcludedExamples.reason_for(metadata)
    metadata[:skip] = "uam: #{reason}" if reason
  end
end
