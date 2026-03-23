# frozen_string_literal: true

module SpecSupport
  # Helpers for inspecting operation contracts in tests.
  module ContractHelper
    def request_body_paths(operation)
      contract_paths(operation.contract.request.body)
    end

    def request_template(operation, section:, mode: :full)
      part = section == :header ? operation.contract.request.header : operation.contract.request.body
      part.template(mode:).to_h
    end

    private

    def contract_paths(part_contract)
      part_contract.paths.map do |entry|
        path = entry.fetch(:path)
        data = entry.except(:path, :kind, :min_occurs, :max_occurs)
        data[:namespace] = nil unless data.key?(:namespace)
        data[:any_content] = true if data.delete(:wildcard)
        data.delete(:list) if data[:list] == false
        [path, data]
      end
    end
  end
end

RSpec.configure do |config|
  config.include SpecSupport::ContractHelper
end
