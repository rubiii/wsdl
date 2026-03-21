# frozen_string_literal: true

WSDL::TestService.define(:rpc_literal, wsdl: 'wsdl/rpc_literal') do
  operation :op1 do
    on data1: 24, data2: 36 do
      { data1: 48, data2: 72 }
    end
  end

  operation :op2 do
    on data1: 1, data2: 2 do
      { data1: 3, data2: 4 }
    end
  end
end
