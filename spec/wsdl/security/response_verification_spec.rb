# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::ResponseVerification do
  describe WSDL::Security::ResponseVerification::Certificate do
    describe '.default' do
      subject(:certificate) { described_class.default }

      it 'returns a Certificate instance' do
        expect(certificate).to be_a(described_class)
      end

      it 'has nil trust_store' do
        expect(certificate.trust_store).to be_nil
      end

      it 'has verify_not_expired enabled' do
        expect(certificate.verify_not_expired).to be true
      end
    end

    describe '#initialize' do
      it 'accepts custom values' do
        certificate = described_class.new(trust_store: :system, verify_not_expired: false)

        expect(certificate.trust_store).to eq(:system)
        expect(certificate.verify_not_expired).to be false
      end

      it 'is immutable' do
        certificate = described_class.new(trust_store: :system, verify_not_expired: true)

        expect(certificate).to be_frozen
      end
    end
  end

  describe WSDL::Security::ResponseVerification::Timestamp do
    describe '.default' do
      subject(:timestamp) { described_class.default }

      it 'returns a Timestamp instance' do
        expect(timestamp).to be_a(described_class)
      end

      it 'has validate enabled' do
        expect(timestamp.validate).to be true
      end

      it 'has 300 seconds tolerance' do
        expect(timestamp.tolerance_seconds).to eq(300)
      end
    end

    describe '#initialize' do
      it 'accepts custom values' do
        timestamp = described_class.new(validate: false, tolerance_seconds: 600)

        expect(timestamp.validate).to be false
        expect(timestamp.tolerance_seconds).to eq(600)
      end

      it 'is immutable' do
        timestamp = described_class.new(validate: true, tolerance_seconds: 300)

        expect(timestamp).to be_frozen
      end
    end
  end

  describe WSDL::Security::ResponseVerification::Options do
    describe '.default' do
      subject(:options) { described_class.default }

      it 'returns an Options instance' do
        expect(options).to be_a(described_class)
      end

      it 'has default certificate options' do
        expect(options.certificate).to be_a(WSDL::Security::ResponseVerification::Certificate)
        expect(options.certificate.trust_store).to be_nil
        expect(options.certificate.verify_not_expired).to be true
      end

      it 'has default timestamp options' do
        expect(options.timestamp).to be_a(WSDL::Security::ResponseVerification::Timestamp)
        expect(options.timestamp.validate).to be true
        expect(options.timestamp.tolerance_seconds).to eq(300)
      end
    end

    describe '.from_config' do
      let(:config) { WSDL::Security::Config.new }

      context 'with default config' do
        subject(:options) { described_class.from_config(config) }

        it 'returns an Options instance' do
          expect(options).to be_a(described_class)
        end

        it 'maps certificate options from config' do
          expect(options.certificate.trust_store).to be_nil
          expect(options.certificate.verify_not_expired).to be true
        end

        it 'maps timestamp options from config' do
          expect(options.timestamp.validate).to be true
          expect(options.timestamp.tolerance_seconds).to eq(300)
        end
      end

      context 'with a duck-typed config without response_verification_options' do
        it 'builds Options from individual config accessors' do
          duck_config = Struct.new(:verification_trust_store, :check_certificate_validity,
                                   :validate_timestamp, :clock_skew)
            .new(
              verification_trust_store: :system,
              check_certificate_validity: false,
              validate_timestamp: false,
              clock_skew: 120
            )

          options = described_class.from_config(duck_config)

          expect(options.certificate.trust_store).to eq(:system)
          expect(options.certificate.verify_not_expired).to be false
          expect(options.timestamp.validate).to be false
          expect(options.timestamp.tolerance_seconds).to eq(120)
        end
      end

      context 'with configured verify_response' do
        subject(:options) { described_class.from_config(config) }

        before do
          config.verify_response(
            trust_store: :system,
            check_validity: false,
            validate_timestamp: false,
            clock_skew: 600
          )
        end

        it 'maps trust_store to certificate.trust_store' do
          expect(options.certificate.trust_store).to eq(:system)
        end

        it 'maps check_validity to certificate.verify_not_expired' do
          expect(options.certificate.verify_not_expired).to be false
        end

        it 'maps validate_timestamp to timestamp.validate' do
          expect(options.timestamp.validate).to be false
        end

        it 'maps clock_skew to timestamp.tolerance_seconds' do
          expect(options.timestamp.tolerance_seconds).to eq(600)
        end
      end
    end

    describe '#initialize' do
      it 'accepts custom nested options' do
        certificate = WSDL::Security::ResponseVerification::Certificate.new(
          trust_store: '/path/to/ca.pem',
          verify_not_expired: false
        )
        timestamp = WSDL::Security::ResponseVerification::Timestamp.new(
          validate: false,
          tolerance_seconds: 60
        )

        options = described_class.new(certificate:, timestamp:)

        expect(options.certificate.trust_store).to eq('/path/to/ca.pem')
        expect(options.certificate.verify_not_expired).to be false
        expect(options.timestamp.validate).to be false
        expect(options.timestamp.tolerance_seconds).to eq(60)
      end

      it 'is immutable' do
        options = described_class.default

        expect(options).to be_frozen
      end
    end
  end
end
