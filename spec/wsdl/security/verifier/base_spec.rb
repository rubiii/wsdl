# frozen_string_literal: true

RSpec.describe WSDL::Security::Verifier::Base do
  it 'raises NotImplementedError for #valid?' do
    subclass = Class.new(described_class)
    instance = subclass.new

    expect { instance.valid? }.to raise_error(NotImplementedError, /must implement #valid\?/)
  end
end
