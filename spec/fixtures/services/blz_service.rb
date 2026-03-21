# frozen_string_literal: true

WSDL::TestService.define(:blz_service, wsdl: 'wsdl/blz_service') do
  operation :getBank do
    on blz: '70070010' do
      {
        details: {
          bezeichnung: 'Deutsche Bank',
          bic: 'DEUTDEMM',
          ort: 'München',
          plz: '80271'
        }
      }
    end

    on blz: '20050550' do
      {
        details: {
          bezeichnung: 'Hamburger Sparkasse',
          bic: 'HASPDEHHXXX',
          ort: 'Hamburg',
          plz: '20454'
        }
      }
    end
  end
end
