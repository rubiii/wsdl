# frozen_string_literal: true

RSpec.describe 'Integration with Marketo Marketo Automation Software' do
  subject(:client) { WSDL::Client.new fixture('wsdl/marketo') }

  let(:service_name) { :MktMktowsApiService }
  let(:port_name)    { :MktowsApiSoapPort }

  it 'returns header parts' do
    operation = client.operation(service_name, port_name, :getLead)
    expect(request_template(operation, section: :header)).to eq({
      AuthenticationHeader: {
        mktowsUserId: 'string',
        requestSignature: 'string',
        requestTimestamp: 'string',
        audit: 'string',
        mode: 'int'
      }
    })
  end

  it 'creates an example body' do
    operation = client.operation(service_name, port_name, :getLead)

    expect(request_template(operation, section: :body)).to eq({
      paramsGetLead: {
        leadKey: {
          keyType: 'string',
          keyValue: 'string'
        }
      }
    })
  end

  it 'builds a request' do
    operation = client.operation(service_name, port_name, :getLead)

    operation.prepare do
      header do
        tag('AuthenticationHeader') do
          tag('mktowsUserId', 'bigcorp1_461839624B16E06BA2D663')
          tag('requestSignature', 'ffbff4d4bef354807481e66dc7540f7890523a87')
          tag('requestTimestamp', '2013-07-30T14:15:06-07:00')
        end
      end
      body do
        tag('paramsGetLead') do
          tag('leadKey') do
            tag('keyType', 'EMAIL')
            tag('keyValue', 'rufus@marketo.com')
          end
        end
      end
    end

    expected = Nokogiri.XML(%(
     <SOAP-ENV:Envelope
       xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
       xmlns:ns1="http://www.marketo.com/mktows/">
       <SOAP-ENV:Header>
         <ns1:AuthenticationHeader>
           <mktowsUserId>bigcorp1_461839624B16E06BA2D663</mktowsUserId>
           <requestSignature>ffbff4d4bef354807481e66dc7540f7890523a87</requestSignature>
           <requestTimestamp>2013-07-30T14:15:06-07:00</requestTimestamp>
         </ns1:AuthenticationHeader>
       </SOAP-ENV:Header>
       <SOAP-ENV:Body>
         <ns1:paramsGetLead>
           <leadKey>
             <keyType>EMAIL</keyType>
             <keyValue>rufus@marketo.com</keyValue>
           </leadKey>
        </ns1:paramsGetLead>
       </SOAP-ENV:Body>
     </SOAP-ENV:Envelope>
   ))

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
