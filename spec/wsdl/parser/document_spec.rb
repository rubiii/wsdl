# frozen_string_literal: true

RSpec.describe WSDL::Parser::Document do
  describe '#messages' do
    it 'works with single element parts' do
      document = get_documents('wsdl/oracle').first

      expect(local_keys(document.messages)).to include(
        'addReportToPageIn', 'addReportToPageOut', 'applyReportDefaultsIn', 'applyReportDefaultsOut'
      )

      # message

      message = fetch_by_local_name(document.messages, 'addReportToPageIn')
      expect(message.name).to eq('addReportToPageIn')

      namespaces = {
        'xmlns:sawsoap' => 'urn://oracle.bi.webservices/v7',
        'xmlns:soap' => 'http://schemas.xmlsoap.org/wsdl/soap/',
        'xmlns:wsdl' => 'http://schemas.xmlsoap.org/wsdl/',
        'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema'
      }
      # On JRuby, there are more namespaces defined.
      namespaces['xmlns:jaxws'] = 'http://java.sun.com/xml/ns/jaxws' if defined?(JRUBY_VERSION)

      expect(message.parts).to eq([
        { name: 'parameters', namespaces:,
          type: nil, element: 'sawsoap:addReportToPage'
}
      ])
    end

    it 'works with multiple type parts' do
      document = get_documents('wsdl/telefonkatalogen').first

      expect(local_keys(document.messages)).to include(
        'sendsmsRequest', 'sendsmsResponse'
      )

      # message

      message = fetch_by_local_name(document.messages, 'sendsmsRequest')
      expect(message.name).to eq('sendsmsRequest')

      namespaces = {
        'xmlns:tns' => 'http://bedrift.telefonkatalogen.no',
        'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:soap' => 'http://schemas.xmlsoap.org/wsdl/soap/',
        'xmlns' => 'http://schemas.xmlsoap.org/wsdl/'
      }

      expect(message.parts).to eq([
        { name: 'sender', namespaces:, type: 'xsd:string', element: nil },
        { name: 'cellular',    namespaces:, type: 'xsd:string', element: nil },
        { name: 'msg',         namespaces:, type: 'xsd:string', element: nil },
        { name: 'smsnumgroup', namespaces:, type: 'xsd:string', element: nil },
        { name: 'emailaddr',   namespaces:, type: 'xsd:string', element: nil },
        { name: 'udh',         namespaces:, type: 'xsd:string', element: nil },
        { name: 'datetime',    namespaces:, type: 'xsd:string', element: nil },
        { name: 'format',      namespaces:, type: 'xsd:string', element: nil },
        { name: 'dlrurl',      namespaces:, type: 'xsd:string', element: nil }
      ])
    end
  end

  describe '#port_types' do
    it 'works with multiple bindings' do
      document = get_documents('wsdl/oracle').first

      expect(local_keys(document.port_types)).to match_array(%w[
        ConditionServiceSoap HtmlViewServiceSoap IBotServiceSoap
        JobManagementServiceSoap MetadataServiceSoap ReplicationServiceSoap
        ReportEditingServiceSoap SAWSessionServiceSoap SecurityServiceSoap
        WebCatalogServiceSoap XmlViewServiceSoap
      ])

      # port type

      port_type = fetch_by_local_name(document.port_types, 'IBotServiceSoap')
      expect(port_type.name).to eq('IBotServiceSoap')

      expect(port_type.operations.keys).to match_array(%w[
        deleteIBot executeIBotNow moveIBot sendMessage
        subscribe unsubscribe writeIBot
      ])

      # port type operation

      port_type_operation = port_type.operations.fetch('moveIBot')
      expect(port_type_operation.name).to eq('moveIBot')

      expect(port_type_operation.input).to be_a(WSDL::Parser::MessageReference)
      expect(port_type_operation.input.name).to be_nil
      expect(port_type_operation.input.message).to eq('sawsoap:moveIBotIn')

      expect(port_type_operation.output).to be_a(WSDL::Parser::MessageReference)
      expect(port_type_operation.output.name).to be_nil
      expect(port_type_operation.output.message).to eq('sawsoap:moveIBotOut')
    end
  end

  describe '#bindings' do
    it 'works with multiple bindings' do
      document = get_documents('wsdl/oracle').first

      expect(local_keys(document.bindings)).to match_array(%w[
        ConditionService HtmlViewService IBotService JobManagementService
        MetadataService ReplicationService ReportEditingService SAWSessionService
        SecurityService WebCatalogService XmlViewService
      ])

      # binding

      binding = fetch_by_local_name(document.bindings, 'SecurityService')

      expect(binding.name).to eq('SecurityService')
      expect(binding.port_type).to eq('sawsoap:SecurityServiceSoap')
      expect(binding.style).to eq('document')
      expect(binding.transport).to eq('http://schemas.xmlsoap.org/soap/http')

      expect(binding.operations.keys).to match_array(%w[
        forgetAccounts getAccountTenantID getAccounts getGlobalPrivilegeACL
        getGlobalPrivileges getGroups getMembers getPermissions getPrivilegesStatus
        isMember joinGroups leaveGroups renameAccounts updateGlobalPrivilegeACL
      ])

      # binding operation

      binding_operation = binding.operations.fetch('getAccounts')
      expect(binding_operation.name).to eq('getAccounts')

      expect(binding_operation.soap_action).to eq('#getAccounts')
      expect(binding_operation.style).to eq('document')
    end
  end

  describe '#services' do
    it 'works with multiple services' do
      document = get_documents('wsdl/oracle').first

      expect(document.services.keys).to match_array(%w[
        SAWSessionService WebCatalogService XmlViewService SecurityService
        ConditionService HtmlViewService IBotService JobManagementService
        MetadataService ReplicationService ReportEditingService
      ])

      service = document.services['ConditionService']
      expect(service.ports.keys).to eq(['ConditionServiceSoap'])

      # soap 1.1 port

      soap_port = service.ports['ConditionServiceSoap']

      expect(soap_port.name).to eq('ConditionServiceSoap')
      expect(soap_port.binding).to eq('sawsoap:ConditionService')

      expect(soap_port.type).to eq(WSDL::NS::WSDL_SOAP_1_1)
      expect(soap_port.location).to eq('https://fap0023-bi.oracleads.com/analytics-ws/saw.dll?SoapImpl=conditionService')
    end

    it 'only knows about the SOAP ports of each service' do
      document = get_documents('wsdl/email_verification').first

      expect(document.services.keys).to eq(['EmailVerNoTestEmail'])

      service = document.services['EmailVerNoTestEmail']
      expect(service.ports.keys).to match_array(%w[
        EmailVerNoTestEmailSoap EmailVerNoTestEmailSoap12
      ])

      # soap 1.1 port

      soap_1_1_port = service.ports['EmailVerNoTestEmailSoap']

      expect(soap_1_1_port.name).to eq('EmailVerNoTestEmailSoap')
      expect(soap_1_1_port.binding).to eq('tns:EmailVerNoTestEmailSoap')

      expect(soap_1_1_port.type).to eq(WSDL::NS::WSDL_SOAP_1_1)
      expect(soap_1_1_port.location).to eq('http://ws.cdyne.com/emailverify/Emailvernotestemail.asmx')

      # soap 1.2 port

      soap_1_2_port = service.ports['EmailVerNoTestEmailSoap12']

      expect(soap_1_2_port.name).to eq('EmailVerNoTestEmailSoap12')
      expect(soap_1_2_port.binding).to eq('tns:EmailVerNoTestEmailSoap12')

      expect(soap_1_2_port.type).to eq(WSDL::NS::WSDL_SOAP_1_2)
      expect(soap_1_2_port.location).to eq('http://ws.cdyne.com/emailverify/Emailvernotestemail.asmx')
    end
  end

  describe 'WSDL 2.0 detection' do
    it 'raises UnsupportedWSDLVersionError for WSDL 2.0 documents' do
      wsdl20 = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <description xmlns="http://www.w3.org/ns/wsdl"
                     targetNamespace="http://example.com/wsdl20">
          <interface name="ExampleInterface"/>
        </description>
      XML

      document = Nokogiri::XML(wsdl20)
      schemas = WSDL::Schema::Collection.new

      expect { described_class.new(document, schemas) }
        .to raise_error(WSDL::UnsupportedWSDLVersionError, /WSDL 2\.0 is not supported/)
    end
  end

  def get_documents(fixture_path)
    documents = WSDL::Parser::DocumentCollection.new
    schemas = WSDL::Schema::Collection.new
    source = WSDL::Resolver::Source.validate_wsdl!(fixture(fixture_path))
    loader = WSDL::Resolver::Loader.new(http_mock,
      sandbox_paths: [File.dirname(File.expand_path(fixture(fixture_path)))])
    importer = WSDL::Resolver::Importer.new(loader, documents, schemas, WSDL::ParseOptions.default)
    importer.import(source.value)
    documents
  end

  def local_keys(collection)
    collection.keys.map(&:local)
  end

  def fetch_by_local_name(collection, name)
    _, value = collection.find { |qname, _| qname.local == name }
    value
  end
end
