# frozen_string_literal: true

module SpecSupport
  # Helpers for inspecting operation contracts in tests.
  module ContractHelper
    def request_template(operation, section:, mode: :full)
      part = section == :header ? operation.contract.request.header : operation.contract.request.body
      part.template(mode:).to_h
    end
  end
end

RSpec.configure do |config|
  config.include SpecSupport::ContractHelper
end
