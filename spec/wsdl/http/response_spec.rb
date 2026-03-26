# frozen_string_literal: true

RSpec.describe WSDL::HTTP::Response do
  describe '.new' do
    it 'creates a response with status, headers, and body' do
      response = described_class.new(status: 200, headers: { 'Content-Type' => 'text/xml' }, body: '<xml/>')

      expect(response.status).to eq(200)
      expect(response.headers).to eq('Content-Type' => 'text/xml')
      expect(response.body).to eq('<xml/>')
    end

    it 'defaults headers to an empty hash' do
      response = described_class.new(status: 200, body: 'ok')

      expect(response.headers).to eq({})
    end

    it 'defaults body to an empty string' do
      response = described_class.new(status: 204)

      expect(response.body).to eq('')
    end

    it 'is frozen (immutable Data)' do
      response = described_class.new(status: 200, body: 'ok')

      expect(response).to be_frozen
    end
  end

  describe 'equality' do
    it 'considers two responses with the same values equal' do
      a = described_class.new(status: 200, body: 'ok')
      b = described_class.new(status: 200, body: 'ok')

      expect(a).to eq(b)
    end

    it 'considers responses with different values not equal' do
      a = described_class.new(status: 200, body: 'ok')
      b = described_class.new(status: 500, body: 'error')

      expect(a).not_to eq(b)
    end
  end
end
