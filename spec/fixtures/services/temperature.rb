# frozen_string_literal: true

WSDL::TestService.define(:temperature, wsdl: 'wsdl/temperature') do
  operation :ConvertTemp do
    on Temperature: 100.0, FromUnit: 'degreeCelsius', ToUnit: 'degreeFahrenheit' do
      { ConvertTempResult: 212.0 }
    end

    on Temperature: 0.0, FromUnit: 'degreeCelsius', ToUnit: 'degreeFahrenheit' do
      { ConvertTempResult: 32.0 }
    end
  end
end
