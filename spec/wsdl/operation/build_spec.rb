# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Operation do
  let(:add_logins) do
    client = WSDL::Client.new fixture('wsdl/bronto')

    service_name = :BrontoSoapApiImplService
    port_name    = :BrontoSoapApiImplPort

    client.operation(service_name, port_name, :addLogins)
  end

  let(:get_mu_bets_lite) do
    client = WSDL::Client.new fixture('wsdl/betfair')

    service_name = port_name = :BFExchangeService
    client.operation(service_name, port_name, :getMUBetsLite)
  end

  let(:vat_account_update_from_data_array) do
    client = WSDL::Client.new fixture('wsdl/arrays_with_attributes')

    service = 'EconomicWebService'
    port = 'EconomicWebServiceSoap'

    client.operation(service, port, 'VatAccount_UpdateFromDataArray')
  end

  let(:zanox_export_service) do
    client = WSDL::Client.new fixture('wsdl/zanox_export_service')

    service = 'ExportService'
    port = 'ExportServiceSoap'

    client.operation(service, port, 'GetPps')
  end

  describe '#build' do
    describe 'multiple calls' do
      let(:body) do
        {
          addLogins: {
            accounts: [
              {
                username: 'first',
                password: 'secret',
                contactInformation: {
                  email: 'first@example.com',
                  _type: 'any'
                }
              }
            ]
          }
        }
      end

      it 'reflects new body values on the next call' do
        add_logins.body = body
        add_logins.build

        add_logins.body = {
          addLogins: {
            accounts: [
              {
                username: 'second',
                password: 'new-secret',
                contactInformation: {
                  email: 'second@example.com',
                  _type: 'any'
                }
              }
            ]
          }
        }

        expect(add_logins.build).to include('<username>second</username>')
      end
    end

    it 'expects Arrays of complex types as Arrays of Hashes' do
      add_logins.body = {
        addLogins: {

          # accounts in an array of complex types
          # which can be represented by hashes.
          accounts: [
            {
              username: 'first',
              password: 'secret',
              contactInformation: {
                email: 'first@example.com'
              }
            },
            {
              username: 'second',
              password: 'ubersecret',
              contactInformation: {
                email: 'second@example.com'
              }
            }
          ]
        }
      }

      expected = Nokogiri.XML('
        <env:Envelope
            xmlns:ns0="http://api.bronto.com/v4"
            xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
          <env:Header>
          </env:Header>
          <env:Body>
            <ns0:addLogins>
              <accounts>
                <username>first</username>
                <password>secret</password>
                <contactInformation>
                  <email>first@example.com</email>
                </contactInformation>
              </accounts>
              <accounts>
                <username>second</username>
                <password>ubersecret</password>
                <contactInformation>
                  <email>second@example.com</email>
                </contactInformation>
              </accounts>
            </ns0:addLogins>
          </env:Body>
        </env:Envelope>
      ')

      expect(Nokogiri.XML(add_logins.build))
        .to be_equivalent_to(expected).respecting_element_order
    end

    it 'raises if it did not receive a Hash for a singular complex type' do
      add_logins.body = {
        addLogins: [
          {
            accounts: {
              username: 'test'
            }
          }
        ]
      }

      expect { add_logins.build }
        .to raise_error(ArgumentError, 'Expected a Hash for the :addLogins complex type')
    end

    it 'raises if it did not receive an Array for an Array of complex types' do
      add_logins.body = {
        addLogins: {

          # accounts is an array and we expect the value
          # to be an array of hashes to reflect this.
          accounts: {
            username: 'test'
          }
        }
      }

      expect { add_logins.build }
        .to raise_error(ArgumentError, 'Expected an Array of Hashes for the :accounts complex type')
    end

    it 'raises if it received an Array for a singular simple type' do
      add_logins.body = {
        addLogins: {
          accounts: [
            {
              username: %w[multiple tests]
            }
          ]
        }
      }

      expect { add_logins.build }
        .to raise_error(ArgumentError, 'Unexpected Array for the :username simple type')
    end

    it 'expectes Arrays of simple types to be represented as Arrays of values' do
      get_mu_bets_lite.body = {
        getMUBetsLite: {
          request: {
            betIds: {
              betId: [1, 2, 3]
            }
          }
        }
      }

      expected = Nokogiri.XML(%(
        <env:Envelope
            xmlns:ns0="http://www.betfair.com/publicapi/v5/BFExchangeService/"
            xmlns:ns1="http://www.betfair.com/publicapi/types/exchange/v5/"
            xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
          <env:Header/>
          <env:Body>
            <ns0:getMUBetsLite>
              <ns0:request>
                <betIds>
                  <ns1:betId>1</ns1:betId>
                  <ns1:betId>2</ns1:betId>
                  <ns1:betId>3</ns1:betId>
                </betIds>
              </ns0:request>
            </ns0:getMUBetsLite>
          </env:Body>
        </env:Envelope>
      ))

      expect(Nokogiri.XML(get_mu_bets_lite.build))
        .to be_equivalent_to(expected).respecting_element_order
    end

    it 'raises if it did not receive an Array for an Array of simple types' do
      get_mu_bets_lite.body = {
        getMUBetsLite: {
          request: {
            betIds: {
              betId: 1
            }
          }
        }
      }

      expect { get_mu_bets_lite.build }
        .to raise_error(ArgumentError, 'Expected an Array of values for the :betId simple type')
    end

    it 'expects Hashes with attributes and matching key to return xml with attributes and text' do
      zanox_export_service.header = {
        zanox: {
          ticket: 'EFB745D691DBFF2DFA9F8B10A4D7A7B1AEA850CD'
        }
      }
      zanox_export_service.body = {
        GetPps: {
          programid: 5574,
          ppsfilter: {
            period: {
              _from: '2013-10-01T00:00:00+02:00',
              _to: '2013-11-12T00:00:00+02:00'
            },
            reviewstate: { reviewstate: 0, _negate: 1 },
            categoryid: {}
          }
        }
      }

      expected = Nokogiri.XML(%(
        <env:Envelope xmlns:ns0="http://services.zanox.com/erp"
                      xmlns:ns1="http://services.zanox.com/erp/Export"
                      xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
          <env:Header>
            <ns0:zanox>
              <ns0:ticket>EFB745D691DBFF2DFA9F8B10A4D7A7B1AEA850CD</ns0:ticket>
            </ns0:zanox>
          </env:Header>
          <env:Body>
            <ns0:GetPps>
              <ns0:programid>5574</ns0:programid>
              <ns1:ppsfilter>
                <ns1:period from="2013-10-01T00:00:00+02:00" to="2013-11-12T00:00:00+02:00"/>
                <ns1:reviewstate negate='1'>0</ns1:reviewstate>
                <ns1:categoryid/>
              </ns1:ppsfilter>
            </ns0:GetPps>
          </env:Body>
        </env:Envelope>))

      expect(Nokogiri.XML(zanox_export_service.build))
        .to be_equivalent_to(expected).respecting_element_order
    end

    it 'expects Array of Hashes with attributes to return Array of complex types with attributes' do
      vat_account_update_from_data_array.body = {
        VatAccount_UpdateFromDataArray: {
          dataArray: {
            VatAccountData: [
              {
                Handle: { VatCode: 'VAT123' },
                VatCode: { _attribute: 'test', _foo: 11, VatCode: 'VAT123' },
                Name: 'ITS',
                Type: 'Ltd',
                RateAsPercent: 17.5,
                AccountHandle: { Number: 123 }, ContraAccountHandle: { Number: 456 },
                _Thaco: 'Testing 1234'
              },
              {
                Handle: { VatCode: 'VAT987' },
                VatCode: 'VAT987',
                Name: 'Banana',
                Type: 'PLC',
                RateAsPercent: 21.12,
                AccountHandle: { Number: 876 }, ContraAccountHandle: { Number: 8756 },
                _Thaco: 'Testing 5678'
              }
            ]
          }
        }
      }

      expected = Nokogiri.XML(%(
        <env:Envelope xmlns:ns0="http://e-conomic.com" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
          <env:Header>
          </env:Header>
          <env:Body>
            <ns0:VatAccount_UpdateFromDataArray>
              <ns0:dataArray>
                <ns0:VatAccountData Thaco="Testing 1234">
                  <ns0:Handle>
                    <ns0:VatCode>VAT123</ns0:VatCode>
                  </ns0:Handle>
                  <ns0:VatCode attribute='test' foo='11'>VAT123</ns0:VatCode>
                  <ns0:Name>ITS</ns0:Name>
                  <ns0:Type>Ltd</ns0:Type>
                  <ns0:RateAsPercent>17.5</ns0:RateAsPercent>
                  <ns0:AccountHandle>
                    <ns0:Number>123</ns0:Number>
                  </ns0:AccountHandle>
                  <ns0:ContraAccountHandle>
                    <ns0:Number>456</ns0:Number>
                  </ns0:ContraAccountHandle>
                </ns0:VatAccountData>
                <ns0:VatAccountData Thaco="Testing 5678">
                  <ns0:Handle>
                    <ns0:VatCode>VAT987</ns0:VatCode>
                  </ns0:Handle>
                  <ns0:VatCode>VAT987</ns0:VatCode>
                  <ns0:Name>Banana</ns0:Name>
                  <ns0:Type>PLC</ns0:Type>
                  <ns0:RateAsPercent>21.12</ns0:RateAsPercent>
                  <ns0:AccountHandle>
                    <ns0:Number>876</ns0:Number>
                  </ns0:AccountHandle>
                  <ns0:ContraAccountHandle>
                    <ns0:Number>8756</ns0:Number>
                  </ns0:ContraAccountHandle>
                </ns0:VatAccountData>
              </ns0:dataArray>
            </ns0:VatAccount_UpdateFromDataArray>
          </env:Body>
        </env:Envelope>))

      expect(Nokogiri.XML(vat_account_update_from_data_array.build))
        .to be_equivalent_to(expected).respecting_element_order
    end
  end
end
