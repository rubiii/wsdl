# frozen_string_literal: true

RSpec.describe 'Telefonkatalogen' do
  # reference: savon#295
  subject(:client) { WSDL::Client.new WSDL.parse(fixture('wsdl/telefonkatalogen')) }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'SendSms' => {
        ports: {
          'SendSmsPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://bedrift.telefonkatalogen.no/tk/websvcsendsms.php',
            operations: [{ name: 'sendsms' }]
          }
        }
      }
    )
  end

  it 'knows the operations' do
    operation = client.operation('SendSms', 'SendSmsPort', 'sendsms')

    expect(operation.soap_action).to eq('sendsms')

    # notice how this contains 9 parts with one element each.
    # it does not include the rpc wrapper.

    expect(operation.contract.request.body.paths).to eq([
      { path: ['sender'],
        kind: :simple,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false },
      { path: ['cellular'],
        kind: :simple,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false },
      { path: ['msg'],
        kind: :simple,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false },
      { path: ['smsnumgroup'],
        kind: :simple,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false },
      { path: ['emailaddr'],
        kind: :simple,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false },
      { path: ['udh'],
        kind: :simple,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false },
      { path: ['datetime'],
        kind: :simple,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false },
      { path: ['format'],
        kind: :simple,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false },
      { path: ['dlrurl'],
        kind: :simple,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false }
    ])
  end
end
