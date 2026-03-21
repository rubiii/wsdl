# frozen_string_literal: true

WSDL::TestService.define(:ratp, wsdl: 'wsdl/ratp') do
  operation :getLines do
    on code: 'M1' do
      {
        return: [
          {
            code: 'M1',
            codeStif: 'C01371',
            id: 'M1',
            image: 'metro_1.png',
            name: 'Métro 1',
            realm: 'r',
            reseau: { code: 'MET', id: 'MET', image: 'metro.png', name: 'Métro' }
          },
          {
            code: 'M1b',
            codeStif: 'C01372',
            id: 'M1b',
            image: 'metro_1bis.png',
            name: 'Métro 1bis',
            realm: 'r',
            reseau: { code: 'MET', id: 'MET', image: 'metro.png', name: 'Métro' }
          }
        ]
      }
    end

    on code: 'UNKNOWN' do
      { return: [] }
    end
  end
end
