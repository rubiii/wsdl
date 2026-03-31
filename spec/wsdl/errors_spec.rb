# frozen_string_literal: true

RSpec.describe 'WSDL error hierarchy' do
  describe WSDL::Error do
    it 'inherits from StandardError' do
      expect(described_class).to be < StandardError
    end

    it 'can be raised with a message' do
      expect { raise described_class, 'something went wrong' }
        .to raise_error(described_class, 'something went wrong')
    end
  end

  describe WSDL::FatalError do
    it 'inherits from WSDL::Error' do
      expect(described_class).to be < WSDL::Error
    end
  end

  describe WSDL::SchemaImportError do
    it 'inherits from WSDL::Error' do
      expect(described_class).to be < WSDL::Error
    end

    it 'stores the location' do
      error = described_class.new('failed', location: 'schema.xsd')
      expect(error.location).to eq('schema.xsd')
    end

    it 'stores the base_location' do
      error = described_class.new('failed', base_location: '/root/service.wsdl')
      expect(error.base_location).to eq('/root/service.wsdl')
    end

    it 'stores the action' do
      error = described_class.new('failed', action: 'import')
      expect(error.action).to eq('import')
    end

    it 'defaults keyword arguments to nil' do
      error = described_class.new('failed')

      expect(error.location).to be_nil
      expect(error.base_location).to be_nil
      expect(error.action).to be_nil
    end

    it 'can be constructed with no arguments' do
      error = described_class.new
      expect(error.message).to eq(described_class.name)
    end

    it 'passes the message through to super alongside keyword arguments' do
      error = described_class.new('import failed', location: 'a.xsd', base_location: '/b', action: 'import')

      expect(error.message).to eq('import failed')
      expect(error.location).to eq('a.xsd')
      expect(error.base_location).to eq('/b')
      expect(error.action).to eq('import')
    end
  end

  describe WSDL::SchemaImportParseError do
    it 'inherits from WSDL::SchemaImportError' do
      expect(described_class).to be < WSDL::SchemaImportError
    end

    it 'inherits the custom initialize with keyword arguments' do
      error = described_class.new('parse failed', location: 'bad.xsd', base_location: '/root', action: 'include')

      expect(error.message).to eq('parse failed')
      expect(error.location).to eq('bad.xsd')
      expect(error.base_location).to eq('/root')
      expect(error.action).to eq('include')
    end
  end

  describe WSDL::UnsupportedWSDLVersionError do
    it 'inherits from WSDL::FatalError' do
      expect(described_class).to be < WSDL::FatalError
    end
  end

  describe WSDL::UnsupportedStyleError do
    it 'inherits from WSDL::Error' do
      expect(described_class).to be < WSDL::Error
    end
  end

  describe WSDL::UnresolvableImportError do
    it 'inherits from WSDL::FatalError' do
      expect(described_class).to be < WSDL::FatalError
    end
  end

  describe WSDL::PathRestrictionError do
    it 'inherits from WSDL::FatalError' do
      expect(described_class).to be < WSDL::FatalError
    end
  end

  describe WSDL::SecurityError do
    it 'inherits from WSDL::FatalError' do
      expect(described_class).to be < WSDL::FatalError
    end
  end

  describe WSDL::SignatureVerificationError do
    it 'inherits from WSDL::SecurityError' do
      expect(described_class).to be < WSDL::SecurityError
    end
  end

  describe WSDL::XMLSecurityError do
    it 'inherits from WSDL::FatalError' do
      expect(described_class).to be < WSDL::FatalError
    end
  end

  describe WSDL::CertificateValidationError do
    it 'inherits from WSDL::SecurityError' do
      expect(described_class).to be < WSDL::SecurityError
    end
  end

  describe WSDL::TimestampValidationError do
    it 'inherits from WSDL::SecurityError' do
      expect(described_class).to be < WSDL::SecurityError
    end
  end

  describe WSDL::UnsupportedAlgorithmError do
    it 'inherits from WSDL::SecurityError' do
      expect(described_class).to be < WSDL::SecurityError
    end

    it 'stores the algorithm_uri' do
      error = described_class.new('unknown algo', algorithm_uri: 'http://example.com/algo')
      expect(error.algorithm_uri).to eq('http://example.com/algo')
    end

    it 'stores the algorithm_type' do
      error = described_class.new('unknown algo', algorithm_type: :digest)
      expect(error.algorithm_type).to eq(:digest)
    end

    it 'defaults keyword arguments to nil' do
      error = described_class.new('unknown algo')

      expect(error.algorithm_uri).to be_nil
      expect(error.algorithm_type).to be_nil
    end

    it 'can be constructed with no arguments' do
      error = described_class.new
      expect(error.message).to eq(described_class.name)
    end

    it 'passes the message through to super alongside keyword arguments' do
      error = described_class.new('bad algo', algorithm_uri: 'http://example.com/algo', algorithm_type: :signature)

      expect(error.message).to eq('bad algo')
      expect(error.algorithm_uri).to eq('http://example.com/algo')
      expect(error.algorithm_type).to eq(:signature)
    end
  end

  describe WSDL::ResourceLimitError do
    it 'inherits from WSDL::FatalError' do
      expect(described_class).to be < WSDL::FatalError
    end

    it 'stores the limit_name' do
      error = described_class.new('too big', limit_name: :max_document_size)
      expect(error.limit_name).to eq(:max_document_size)
    end

    it 'stores the limit_value' do
      error = described_class.new('too big', limit_value: 1_000_000)
      expect(error.limit_value).to eq(1_000_000)
    end

    it 'stores the actual_value' do
      error = described_class.new('too big', actual_value: 2_000_000)
      expect(error.actual_value).to eq(2_000_000)
    end

    it 'defaults keyword arguments to nil' do
      error = described_class.new('too big')

      expect(error.limit_name).to be_nil
      expect(error.limit_value).to be_nil
      expect(error.actual_value).to be_nil
    end

    it 'can be constructed with no arguments' do
      error = described_class.new
      expect(error.message).to eq(described_class.name)
    end

    it 'passes the message through to super alongside keyword arguments' do
      error = described_class.new('exceeded', limit_name: :max_schemas, limit_value: 100, actual_value: 200)

      expect(error.message).to eq('exceeded')
      expect(error.limit_name).to eq(:max_schemas)
      expect(error.limit_value).to eq(100)
      expect(error.actual_value).to eq(200)
    end
  end

  describe WSDL::UnresolvedReferenceError do
    it 'inherits from WSDL::Error' do
      expect(described_class).to be < WSDL::Error
    end

    it 'stores the reference_type' do
      error = described_class.new('not found', reference_type: :binding)
      expect(error.reference_type).to eq(:binding)
    end

    it 'stores the reference_name' do
      error = described_class.new('not found', reference_name: 'MyBinding')
      expect(error.reference_name).to eq('MyBinding')
    end

    it 'stores the namespace' do
      error = described_class.new('not found', namespace: 'http://example.com')
      expect(error.namespace).to eq('http://example.com')
    end

    it 'stores the context' do
      error = described_class.new('not found', context: 'building message')
      expect(error.context).to eq('building message')
    end

    it 'defaults keyword arguments to nil' do
      error = described_class.new('not found')

      expect(error.reference_type).to be_nil
      expect(error.reference_name).to be_nil
      expect(error.namespace).to be_nil
      expect(error.context).to be_nil
    end

    it 'can be constructed with no arguments' do
      error = described_class.new
      expect(error.message).to eq(described_class.name)
    end

    it 'passes the message through to super alongside keyword arguments' do
      error = described_class.new('missing', reference_type: :binding, reference_name: 'Foo',
        namespace: 'http://example.com', context: 'resolving port')

      expect(error.message).to eq('missing')
      expect(error.reference_type).to eq(:binding)
      expect(error.reference_name).to eq('Foo')
      expect(error.namespace).to eq('http://example.com')
      expect(error.context).to eq('resolving port')
    end
  end

  describe WSDL::DuplicateDefinitionError do
    it 'inherits from WSDL::Error' do
      expect(described_class).to be < WSDL::Error
    end

    it 'stores the component_type' do
      error = described_class.new('duplicate', component_type: :message)
      expect(error.component_type).to eq(:message)
    end

    it 'stores the definition_key' do
      error = described_class.new('duplicate', definition_key: 'MyMessage')
      expect(error.definition_key).to eq('MyMessage')
    end

    it 'defaults keyword arguments to nil' do
      error = described_class.new('duplicate')

      expect(error.component_type).to be_nil
      expect(error.definition_key).to be_nil
    end

    it 'can be constructed with no arguments' do
      error = described_class.new
      expect(error.message).to eq(described_class.name)
    end

    it 'passes the message through to super alongside keyword arguments' do
      error = described_class.new('duplicate found', component_type: :service, definition_key: 'MyService')

      expect(error.message).to eq('duplicate found')
      expect(error.component_type).to eq(:service)
      expect(error.definition_key).to eq('MyService')
    end
  end

  describe WSDL::SchemaVersionError do
    it 'inherits from WSDL::Error' do
      expect(described_class).to be < WSDL::Error
    end

    it 'stores the expected_version' do
      error = described_class.new('mismatch', expected_version: 2)
      expect(error.expected_version).to eq(2)
    end

    it 'stores the actual_version' do
      error = described_class.new('mismatch', actual_version: 1)
      expect(error.actual_version).to eq(1)
    end

    it 'defaults keyword arguments to nil' do
      error = described_class.new('mismatch')

      expect(error.expected_version).to be_nil
      expect(error.actual_version).to be_nil
    end

    it 'can be constructed with no arguments' do
      error = described_class.new
      expect(error.message).to eq(described_class.name)
    end

    it 'passes the message through to super alongside keyword arguments' do
      error = described_class.new('version mismatch', expected_version: 2, actual_version: 999)

      expect(error.message).to eq('version mismatch')
      expect(error.expected_version).to eq(2)
      expect(error.actual_version).to eq(999)
    end
  end

  describe WSDL::RequestDefinitionError do
    it 'inherits from WSDL::Error' do
      expect(described_class).to be < WSDL::Error
    end
  end

  describe WSDL::RequestValidationError do
    it 'inherits from WSDL::Error' do
      expect(described_class).to be < WSDL::Error
    end
  end

  describe WSDL::RequestDslError do
    it 'inherits from WSDL::Error' do
      expect(described_class).to be < WSDL::Error
    end
  end

  describe WSDL::RequestSecurityConflictError do
    it 'inherits from WSDL::FatalError' do
      expect(described_class).to be < WSDL::FatalError
    end
  end

  describe WSDL::UnsafeRedirectError do
    it 'inherits from WSDL::FatalError' do
      expect(described_class).to be < WSDL::FatalError
    end

    it 'stores the target_url' do
      error = described_class.new('blocked', target_url: 'http://169.254.169.254/metadata')
      expect(error.target_url).to eq('http://169.254.169.254/metadata')
    end

    it 'defaults target_url to nil' do
      error = described_class.new('blocked')
      expect(error.target_url).to be_nil
    end

    it 'can be constructed with no arguments' do
      error = described_class.new
      expect(error.message).to eq(described_class.name)
    end

    it 'passes the message through to super alongside keyword arguments' do
      error = described_class.new('ssrf blocked', target_url: 'http://10.0.0.1/admin')

      expect(error.message).to eq('ssrf blocked')
      expect(error.target_url).to eq('http://10.0.0.1/admin')
    end
  end

  describe WSDL::TooManyRedirectsError do
    it 'inherits from WSDL::FatalError' do
      expect(described_class).to be < WSDL::FatalError
    end
  end

  describe WSDL::SealedCollectionError do
    it 'inherits from WSDL::Error' do
      expect(described_class).to be < WSDL::Error
    end
  end

  describe 'rescue hierarchy' do
    it 'allows rescuing all errors with WSDL::Error' do
      expect { raise WSDL::SignatureVerificationError, 'tampered' }
        .to raise_error(WSDL::Error)
    end

    it 'allows rescuing all security errors with WSDL::SecurityError' do
      expect { raise WSDL::CertificateValidationError, 'expired' }
        .to raise_error(WSDL::SecurityError)
    end

    it 'allows rescuing all fatal errors with WSDL::FatalError' do
      expect { raise WSDL::PathRestrictionError, 'traversal' }
        .to raise_error(WSDL::FatalError)
    end

    it 'does not catch recoverable errors with rescue WSDL::FatalError' do
      error = WSDL::UnsupportedStyleError.new('rpc/encoded')

      expect(error).to be_a(WSDL::Error)
      expect(error).not_to be_a(WSDL::FatalError)
    end
  end
end
