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

  context 'with a live mock service', :test_service do
    subject(:client) { WSDL::Client.new(service.wsdl_url) }

    let(:service) { WSDL::TestService[:marketo] }

    before do
      service.start
    end

    it 'returns campaigns with headers, arrays, and integer types' do
      operation = client.operation(service_name, port_name, :getCampaignsForSource)

      operation.prepare do
        header do
          tag('AuthenticationHeader') do
            tag('mktowsUserId', 'user_123')
            tag('requestSignature', 'sig_abc')
            tag('requestTimestamp', '2025-01-15T10:00:00Z')
            tag('audit', '')
            tag('mode', 1)
          end
        end
        body do
          tag('paramsGetCampaignsForSource') do
            tag('source', 'MKTOWS')
            tag('name', 'Welcome')
            tag('exactName', false)
          end
        end
      end
      response = operation.invoke
      result = response.body[:successGetCampaignsForSource][:result]

      expect(result[:returnCount]).to eq(2)

      campaigns = result[:campaignRecordList][:campaignRecord]
      expect(campaigns).to be_an(Array)
      expect(campaigns.size).to eq(2)
      expect(campaigns[0][:id]).to eq(1001)
      expect(campaigns[0][:name]).to eq('Welcome Email')
      expect(campaigns[1][:id]).to eq(1002)
    end

    it 'returns empty results for no matches' do
      operation = client.operation(service_name, port_name, :getCampaignsForSource)

      operation.prepare do
        header do
          tag('AuthenticationHeader') do
            tag('mktowsUserId', 'user_123')
            tag('requestSignature', 'sig_abc')
            tag('requestTimestamp', '2025-01-15T10:00:00Z')
            tag('audit', '')
            tag('mode', 1)
          end
        end
        body do
          tag('paramsGetCampaignsForSource') do
            tag('source', 'MKTOWS')
            tag('name', 'Nonexistent')
            tag('exactName', true)
          end
        end
      end
      response = operation.invoke
      result = response.body[:successGetCampaignsForSource][:result]

      expect(result[:returnCount]).to eq(0)
      expect(result[:campaignRecordList]).to eq({})
    end
  end
end
