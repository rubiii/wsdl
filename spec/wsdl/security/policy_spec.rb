# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::Policy do
  describe '.default' do
    it 'returns a frozen policy with frozen child policies' do
      policy = described_class.default

      expect(policy).to be_frozen
      expect(policy.request).to be_frozen
      expect(policy.response).to be_frozen
    end
  end

  describe '#with_request and #with_response' do
    it 'returns new frozen policy instances' do
      original = described_class.default
      updated_request = original.request.with_username_token(
        WSDL::Security::RequestPolicy::UsernameToken.new(
          username: 'user',
          password: 'secret',
          digest: false,
          created_at: nil
        )
      )
      updated_response = original.response.with_mode(WSDL::Security::ResponsePolicy::MODE_REQUIRED)

      with_request = original.with_request(updated_request)
      with_response = original.with_response(updated_response)

      expect(with_request).to be_frozen
      expect(with_response).to be_frozen
      expect(with_request).not_to equal(original)
      expect(with_response).not_to equal(original)
      expect(original.request.username_token?).to be(false)
      expect(with_request.request.username_token?).to be(true)
      expect(original.response.mode).to eq(WSDL::Security::ResponsePolicy::MODE_DISABLED)
      expect(with_response.response.mode).to eq(WSDL::Security::ResponsePolicy::MODE_REQUIRED)
    end
  end
end
