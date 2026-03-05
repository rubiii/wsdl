# frozen_string_literal: true

require 'spec_helper'

describe 'Request DSL' do
  let(:client) { WSDL::Client.new(fixture('wsdl/temperature'), strict_schema: false) }
  let(:operation) { client.operation('ConvertTemperature', 'ConvertTemperatureSoap12', 'ConvertTemp') }

  it 'defaults top-level content to SOAP Body' do
    operation.prepare do
      tag('ConvertTemp') do
        tag('Temperature', 30)
        tag('FromUnit', 'degreeCelsius')
        tag('ToUnit', 'degreeFahrenheit')
      end
    end

    xml = operation.to_xml
    expect(xml).to include('<env:Body>')
    expect(xml).to include('ConvertTemp')
  end

  it 'supports explicit header section' do
    operation.prepare do
      header do
        tag('AuthToken', 'secret')
      end

      tag('ConvertTemp') do
        tag('Temperature', 30)
        tag('FromUnit', 'degreeCelsius')
        tag('ToUnit', 'degreeFahrenheit')
      end
    end

    xml = operation.to_xml
    expect(xml).to include('<AuthToken>secret</AuthToken>')
  end

  it 'supports cdata, comments and processing instructions' do
    operation.prepare do
      tag('ConvertTemp') do
        comment('note')
        tag('Temperature') do
          cdata('<raw>30</raw>')
        end
        pi('test', 'value="x"')
        tag('FromUnit', 'degreeCelsius')
        tag('ToUnit', 'degreeFahrenheit')
      end
    end

    xml = operation.to_xml
    expect(xml).to include('<!--note-->')
    expect(xml).to include('<![CDATA[<raw>30</raw>]]>')
    expect(xml).to include('<?test value="x"?>')
  end

  it 'escapes text and attribute values' do
    operation.prepare do
      tag('ConvertTemp') do
        tag('Temperature', '30')
        tag('FromUnit') do
          attribute('name', 'A&B<"\'')

          text('A&B<"\'')
        end
        tag('ToUnit', 'degreeFahrenheit')
      end
    end

    xml = operation.to_xml
    expect(xml).to include('name="A&amp;B&lt;&quot;\'"')
    expect(xml).to include('A&amp;B&lt;"\'')
  end

  it 'raises RequestDslError for invalid XML names' do
    expect {
      operation.prepare do
        tag('1bad')
      end
    }.to raise_error(WSDL::RequestDslError, /Invalid XML local name/)
  end

  it 'raises RequestDslError for undeclared QName prefixes' do
    expect {
      operation.prepare do
        tag('ord:ConvertTemp')
      end
    }.to raise_error(WSDL::RequestDslError, /Undeclared namespace prefix/)
  end

  it 'rejects overriding reserved prefixes' do
    expect {
      operation.prepare do
        xmlns('wsse', 'http://example.com/custom')
      end
    }.to raise_error(WSDL::RequestDslError, /reserved and cannot be overridden/)
  end

  it 'enforces request resource limits during AST construction' do
    limited_client = WSDL::Client.new(
      fixture('wsdl/temperature'),
      strict_schema: false,
      limits: WSDL.limits.with(max_request_elements: 2)
    )
    limited_operation = limited_client.operation('ConvertTemperature', 'ConvertTemperatureSoap12', 'ConvertTemp')

    expect {
      limited_operation.prepare do
        tag('ConvertTemp') do
          tag('Temperature', 30)
          tag('FromUnit', 'degreeCelsius')
          tag('ToUnit', 'degreeFahrenheit')
        end
      end
    }.to raise_error(WSDL::ResourceLimitError, /exceeds limit/)
  end

  it 'supports ws_security block with implicit receiver' do
    operation.prepare do
      ws_security do
        timestamp
      end

      tag('ConvertTemp') do
        tag('Temperature', 30)
        tag('FromUnit', 'degreeCelsius')
        tag('ToUnit', 'degreeFahrenheit')
      end
    end

    xml = operation.to_xml
    expect(xml).to include('wsse:Security')
    expect(xml).to include('mustUnderstand="true"')
  end

  it 'rejects nested section blocks (body inside header)' do
    expect {
      operation.prepare do
        header do
          body do
            tag('Foo')
          end
        end
      end
    }.to raise_error(WSDL::RequestDslError, /Cannot nest body inside another section block/)
  end

  it 'rejects nested section blocks (header inside body)' do
    expect {
      operation.prepare do
        body do
          header do
            tag('Foo')
          end
        end
      end
    }.to raise_error(WSDL::RequestDslError, /Cannot nest header inside another section block/)
  end

  it 'allows verify_response-only config without triggering outbound conflict checks' do
    # Configure only response verification (no outbound security)
    # Then add manual header content that would conflict if outbound security was configured
    expect {
      operation.prepare do
        header do
          # This would conflict with generated wsse:Security if outbound security was configured
          xmlns('custom_wsse', WSDL::Security::Constants::NS::Security::WSSE)
          tag('custom_wsse:Security') do
            tag('custom_wsse:CustomToken', 'value')
          end
        end

        ws_security do
          verify_response mode: :required
        end

        tag('ConvertTemp') do
          tag('Temperature', 30)
          tag('FromUnit', 'degreeCelsius')
          tag('ToUnit', 'degreeFahrenheit')
        end
      end
    }.not_to raise_error

    xml = operation.to_xml
    # Should have manual Security header but no generated wsse:Security
    expect(xml).to include('<custom_wsse:Security>')
    expect(xml).to include('<custom_wsse:CustomToken>value</custom_wsse:CustomToken>')
  end

  it 'raises RequestDslError with helpful message for unknown methods' do
    raised_error = nil
    expect {
      operation.prepare do
        unknown_method('value')
      end
    }.to raise_error(WSDL::RequestDslError) { |e| raised_error = e }

    expect(raised_error.message).to include('Unknown request DSL method :unknown_method')
    expect(raised_error.message).to include("Use tag('unknown_method') for elements")
    expect(raised_error.message).to include(':tag')
    expect(raised_error.message).to include(':header')
    expect(raised_error.message).to include(':body')
    expect(raised_error.message).to include(':ws_security')
    expect(raised_error.message).to include(':text')
    expect(raised_error.message).to include(':cdata')
    expect(raised_error.message).to include(':comment')
    expect(raised_error.message).to include(':pi')
    expect(raised_error.message).to include(':xmlns')
    expect(raised_error.message).to include(':attribute')
  end

  it 'supports the attribute method for setting attributes on elements' do
    operation.prepare do
      tag('ConvertTemp') do
        attribute('version', '1.0')
        tag('Temperature', 30)
        tag('FromUnit', 'degreeCelsius')
        tag('ToUnit', 'degreeFahrenheit')
      end
    end

    xml = operation.to_xml
    expect(xml).to include('version="1.0"')
  end
end
