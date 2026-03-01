# frozen_string_literal: true

require 'spec_helper'

describe 'Nillable elements' do
  let(:parser_result) { WSDL::Parser::Result.new(fixture('wsdl/nillable_elements'), http_mock) }
  let(:operation_info) { parser_result.operation('UserService', 'UserServicePort', 'CreateUser') }

  describe 'element nillable attribute parsing' do
    let(:body_parts) { operation_info.input.body_parts }
    let(:create_user_element) { body_parts.first }

    it 'parses nillable="true" on simple type elements' do
      # email has nillable="true"
      email_element = create_user_element.children.find { |c| c.name == 'email' }
      expect(email_element.nillable?).to be true

      # displayName has nillable="true"
      display_name_element = create_user_element.children.find { |c| c.name == 'displayName' }
      expect(display_name_element.nillable?).to be true
    end

    it 'parses nillable="false" (default) on simple type elements' do
      # username does not have nillable attribute
      username_element = create_user_element.children.find { |c| c.name == 'username' }
      expect(username_element.nillable?).to be false

      # phoneNumber does not have nillable attribute
      phone_element = create_user_element.children.find { |c| c.name == 'phoneNumber' }
      expect(phone_element.nillable?).to be false
    end

    it 'parses nillable="true" on complex type elements' do
      # address has nillable="true"
      address_element = create_user_element.children.find { |c| c.name == 'address' }
      expect(address_element.nillable?).to be true
    end

    it 'parses nillable="true" on array elements' do
      # tags has nillable="true" and maxOccurs="unbounded"
      tags_element = create_user_element.children.find { |c| c.name == 'tags' }
      expect(tags_element.nillable?).to be true
      expect(tags_element.singular?).to be false
    end

    it 'parses nillable on nested elements' do
      address_element = create_user_element.children.find { |c| c.name == 'address' }

      street_element = address_element.children.find { |c| c.name == 'street' }
      expect(street_element.nillable?).to be true

      city_element = address_element.children.find { |c| c.name == 'city' }
      expect(city_element.nillable?).to be false

      zip_element = address_element.children.find { |c| c.name == 'zipCode' }
      expect(zip_element.nillable?).to be true
    end
  end

  describe 'xsi:nil serialization' do
    context 'when a nillable simple type element has a nil value' do
      subject(:envelope) { WSDL::Builder::Envelope.new(operation_info, nil, body) }

      let(:body) do
        {
          CreateUser: {
            username: 'johndoe',
            email: nil,          # nillable="true" - should get xsi:nil="true"
            displayName: nil     # nillable="true" - should get xsi:nil="true"
          }
        }
      end

      it 'includes the xsi namespace on the envelope' do
        xml = envelope.to_s
        expect(xml).to include('xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"')
      end

      it 'serializes nil values with xsi:nil="true"' do
        xml = envelope.to_s
        expect(xml).to include('xsi:nil="true"')
      end

      it 'returns semantically correct XML' do
        expected = Nokogiri.XML(%(
          <env:Envelope
              xmlns:lol0="http://example.com/nillable/"
              xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <env:Header/>
            <env:Body>
              <lol0:CreateUser>
                <lol0:username>johndoe</lol0:username>
                <lol0:email xsi:nil="true"/>
                <lol0:displayName xsi:nil="true"/>
              </lol0:CreateUser>
            </env:Body>
          </env:Envelope>
        ))

        expect(envelope.to_s)
          .to be_equivalent_to(expected).respecting_element_order
      end
    end

    context 'when a non-nillable element has a nil value' do
      subject(:envelope) { WSDL::Builder::Envelope.new(operation_info, nil, body) }

      let(:body) do
        {
          CreateUser: {
            username: 'johndoe',
            phoneNumber: nil,    # not nillable - should get empty element
            displayName: 'John'
          }
        }
      end

      it 'does not include the xsi namespace when only non-nillable elements are nil' do
        xml = envelope.to_s
        expect(xml).not_to include('xmlns:xsi')
      end

      it 'serializes nil value as empty element' do
        xml = envelope.to_s
        expect(xml).to include('<lol0:phoneNumber/>')
        expect(xml).not_to include('xsi:nil')
      end
    end

    context 'when a nillable complex type element has a nil value' do
      subject(:envelope) { WSDL::Builder::Envelope.new(operation_info, nil, body) }

      let(:body) do
        {
          CreateUser: {
            username: 'johndoe',
            displayName: 'John',
            address: nil         # nillable="true" complex type
          }
        }
      end

      it 'serializes nil complex type with xsi:nil="true"' do
        xml = envelope.to_s
        expect(xml).to include('<lol0:address xsi:nil="true"/>')
      end
    end

    context 'when nested nillable elements have nil values' do
      subject(:envelope) { WSDL::Builder::Envelope.new(operation_info, nil, body) }

      let(:body) do
        {
          CreateUser: {
            username: 'johndoe',
            displayName: 'John',
            address: {
              street: nil,       # nillable="true"
              city: 'New York',
              zipCode: nil       # nillable="true"
            }
          }
        }
      end

      it 'serializes nested nil values with xsi:nil="true"' do
        xml = envelope.to_s
        expect(xml).to include('<lol0:street xsi:nil="true"/>')
        expect(xml).to include('<lol0:zipCode xsi:nil="true"/>')
      end

      it 'includes the city with its value' do
        xml = envelope.to_s
        expect(xml).to include('<lol0:city>New York</lol0:city>')
      end
    end

    context 'when an array contains nil values and elements are nillable' do
      subject(:envelope) { WSDL::Builder::Envelope.new(operation_info, nil, body) }

      let(:body) do
        {
          CreateUser: {
            username: 'johndoe',
            displayName: 'John',
            tags: ['ruby', nil, 'developer', nil] # nillable="true" array
          }
        }
      end

      it 'serializes nil array elements with xsi:nil="true"' do
        xml = envelope.to_s

        # Count occurrences
        expect(xml.scan('<lol0:tags>ruby</lol0:tags>').length).to eq(1)
        expect(xml.scan('<lol0:tags>developer</lol0:tags>').length).to eq(1)
        expect(xml.scan('<lol0:tags xsi:nil="true"/>').length).to eq(2)
      end
    end

    context 'when no nil values are present' do
      subject(:envelope) { WSDL::Builder::Envelope.new(operation_info, nil, body) }

      let(:body) do
        {
          CreateUser: {
            username: 'johndoe',
            email: 'john@example.com',
            displayName: 'John Doe',
            phoneNumber: '555-1234'
          }
        }
      end

      it 'does not include the xsi namespace' do
        xml = envelope.to_s
        expect(xml).not_to include('xmlns:xsi')
      end

      it 'does not include xsi:nil attributes' do
        xml = envelope.to_s
        expect(xml).not_to include('xsi:nil')
      end
    end

    context 'with mixed nillable and non-nillable nil values' do
      subject(:envelope) { WSDL::Builder::Envelope.new(operation_info, nil, body) }

      let(:body) do
        {
          CreateUser: {
            username: 'johndoe',
            email: nil,          # nillable - gets xsi:nil="true"
            displayName: 'John',
            phoneNumber: nil     # not nillable - gets empty element
          }
        }
      end

      it 'correctly differentiates between nillable and non-nillable elements' do
        xml = envelope.to_s

        # Nillable element gets xsi:nil="true"
        expect(xml).to include('<lol0:email xsi:nil="true"/>')

        # Non-nillable element gets empty element
        expect(xml).to include('<lol0:phoneNumber/>')
        expect(xml).not_to include('<lol0:phoneNumber xsi:nil')
      end

      it 'includes xsi namespace because at least one nillable element is nil' do
        xml = envelope.to_s
        expect(xml).to include('xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"')
      end
    end
  end
end
