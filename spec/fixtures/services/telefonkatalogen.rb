# frozen_string_literal: true

WSDL::TestService.define(:telefonkatalogen, wsdl: 'wsdl/telefonkatalogen') do
  operation :sendsms do
    on cellular: '4712345678', msg: 'Hello' do
      { body: 'OK: Message queued' }
    end

    on cellular: '0000000000' do
      { body: 'ERROR: Invalid number' }
    end
  end
end
