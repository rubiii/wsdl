# frozen_string_literal: true

RSpec.describe 'Equifax' do
  subject(:client) { WSDL::Client.new fixture('wsdl/equifax') }

  let(:service_name) { :canadav2 }
  let(:port_name)    { :canadaHttpPortV2 }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'canadav2' => {
        ports: {
          'canadaHttpPortV2' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://pilot.eidverifier.com/uru/soap/cert/canadav2'
          }
        }
      }
    )
  end

  it 'knows operations with attributes and attribute groups' do
    operation = client.operation(service_name, port_name, 'startTransaction')

    expect(operation.soap_action).to eq('')
    expect(operation.endpoint).to eq('https://pilot.eidverifier.com/uru/soap/cert/canadav2')

    ns1 = 'http://eid.equifax.com/soap/schema/canada/v2'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['InitialRequest'],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[InitialRequest Identity],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[InitialRequest Identity Name],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[InitialRequest Identity Name FirstName],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity Name MiddleName],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity Name MiddleInitial],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity Name LastName],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity Name Suffix],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity Address],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: false,
        min_occurs: '1',
        max_occurs: '3',
        attributes: [{ name: 'timeAtAddress', type: 'nonNegativeInteger', required: false, list: false },
                     { name: 'addressType', type: 'string', required: true, list: false }
],
        wildcard: false
},
      { path: %w[InitialRequest Identity Address FreeFormAddress],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[InitialRequest Identity Address FreeFormAddress AddressLine],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: false,
        min_occurs: '1',
        max_occurs: '6',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity Address HybridAddress],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[InitialRequest Identity Address HybridAddress AddressLine],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: false,
        min_occurs: '1',
        max_occurs: '6',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity Address HybridAddress City],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity Address HybridAddress Province],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity Address HybridAddress PostalCode],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity SIN],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity DateOfBirth],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[InitialRequest Identity DateOfBirth Day],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'positiveInteger',
        list: false
},
      { path: %w[InitialRequest Identity DateOfBirth Month],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'positiveInteger',
        list: false
},
      { path: %w[InitialRequest Identity DateOfBirth Year],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'positiveInteger',
        list: false
},
      { path: %w[InitialRequest Identity DriversLicense],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        attributes: [{ name: 'driversLicenseAddressType', type: 'string', required: false, list: false }],
        wildcard: false
},
      { path: %w[InitialRequest Identity DriversLicense Number],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity DriversLicense Province],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity PhoneNumber],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: false,
        min_occurs: '0',
        max_occurs: '3',
        attributes: [{ name: 'phoneType', type: 'string', required: false, list: false }],
        wildcard: false
},
      { path: %w[InitialRequest Identity PhoneNumber AreaCode],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity PhoneNumber Exchange],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity PhoneNumber Number],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity PhoneNumber PhoneNumber],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity Email],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity IPAddress],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity CreditCardNumber],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest Identity CustomerId],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest ProcessingOptions],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[InitialRequest ProcessingOptions Language],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'string',
        list: false
},
      { path: %w[InitialRequest ProcessingOptions EnvironmentOverride],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'string',
        list: false
}
    ])
  end

  it 'creates an example body with attributes' do
    operation = client.operation(service_name, port_name, :startTransaction)

    expect(request_template(operation, section: :body)).to eq(
      InitialRequest: {
        Identity: {
          Name: {
            FirstName: 'string',
            MiddleName: 'string',
            MiddleInitial: 'string',
            LastName: 'string',
            Suffix: 'string'
          },
          Address: [
            {
              FreeFormAddress: {
                AddressLine: ['string']
              },
              HybridAddress: {
                AddressLine: ['string'],
                City: 'string',
                Province: 'string',
                PostalCode: 'string'
              },

              # attributes are prefixed with an underscore.
              _timeAtAddress: 'nonNegativeInteger',
              _addressType: 'string'
            }
          ],
          SIN: 'string',
          DateOfBirth: {
            Day: 'positiveInteger',
            Month: 'positiveInteger',
            Year: 'positiveInteger'
          },
          DriversLicense: {
            Number: 'string',
            Province: 'string',

            # another attribute
            _driversLicenseAddressType: 'string'
          },
          PhoneNumber: [
            {
              AreaCode: 'string',
              Exchange: 'string',
              Number: 'string',
              PhoneNumber: 'string',

              # another attribute
              _phoneType: 'string'
            }
          ],
          Email: 'string',
          IPAddress: 'string',
          CreditCardNumber: 'string',
          CustomerId: 'string'
        },
        ProcessingOptions: {
          Language: 'string',
          EnvironmentOverride: 'string'
        }
      }
    )
  end

  it 'creates a request with attributes' do
    operation = client.operation(service_name, port_name, :startTransaction)

    operation.prepare do
      body do
        tag('InitialRequest') do
          tag('Identity') do
            tag('Name') do
              tag('FirstName', 'John')
              tag('MiddleName', '')
              tag('MiddleInitial', '')
              tag('LastName', 'Lennon')
            end
            tag('Address') do
              attribute('timeAtAddress', 3)
              attribute('addressType', 'public')
              tag('FreeFormAddress') do
                tag('AddressLine', 'The original')
                tag('AddressLine', 'Abbey Road, London')
              end
              tag('HybridAddress') do
                tag('AddressLine', 'The original')
                tag('AddressLine', 'Abbey Road')
                tag('City', 'London')
                tag('Province', 'Camden')
                tag('PostalCode', 'NW8 9BS')
              end
            end
          end
          tag('ProcessingOptions') do
            tag('Language', 'en')
          end
        end
      end
    end

    expected = Nokogiri.XML('
      <env:Envelope
          xmlns:ns0="http://eid.equifax.com/soap/schema/canada/v2"
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header/>
        <env:Body>
          <ns0:InitialRequest>
            <ns0:Identity>
              <ns0:Name>
                <ns0:FirstName>John</ns0:FirstName>
                <ns0:MiddleName></ns0:MiddleName>
                <ns0:MiddleInitial></ns0:MiddleInitial>
                <ns0:LastName>Lennon</ns0:LastName>
              </ns0:Name>
              <ns0:Address timeAtAddress="3" addressType="public">
                <ns0:FreeFormAddress>
                  <ns0:AddressLine>The original</ns0:AddressLine>
                  <ns0:AddressLine>Abbey Road, London</ns0:AddressLine>
                </ns0:FreeFormAddress>
                <ns0:HybridAddress>
                  <ns0:AddressLine>The original</ns0:AddressLine>
                  <ns0:AddressLine>Abbey Road</ns0:AddressLine>
                  <ns0:City>London</ns0:City>
                  <ns0:Province>Camden</ns0:Province>
                  <ns0:PostalCode>NW8 9BS</ns0:PostalCode>
                </ns0:HybridAddress>
              </ns0:Address>
            </ns0:Identity>
            <ns0:ProcessingOptions>
              <ns0:Language>en</ns0:Language>
            </ns0:ProcessingOptions>
          </ns0:InitialRequest>
        </env:Body>
      </env:Envelope>
    ')

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
