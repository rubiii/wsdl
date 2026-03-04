# frozen_string_literal: true

require 'spec_helper'

describe 'Nillable elements' do
  let(:parser_result) { WSDL::Parser::Result.new(fixture('wsdl/nillable_elements'), http_mock) }
  let(:operation_info) { parser_result.operation('UserService', 'UserServicePort', 'CreateUser') }

  describe 'element nillable attribute parsing' do
    let(:body_parts) { operation_info.input.body_parts }
    let(:create_user_element) { body_parts.first }

    it 'parses nillable="true" on simple type elements' do
      email_element = create_user_element.children.find { |c| c.name == 'email' }
      display_name_element = create_user_element.children.find { |c| c.name == 'displayName' }

      expect(email_element.nillable?).to be(true)
      expect(display_name_element.nillable?).to be(true)
    end

    it 'parses nillable="false" (default) on simple type elements' do
      username_element = create_user_element.children.find { |c| c.name == 'username' }
      phone_element = create_user_element.children.find { |c| c.name == 'phoneNumber' }

      expect(username_element.nillable?).to be(false)
      expect(phone_element.nillable?).to be(false)
    end

    it 'parses nillable="true" on complex and array elements' do
      address_element = create_user_element.children.find { |c| c.name == 'address' }
      tags_element = create_user_element.children.find { |c| c.name == 'tags' }

      expect(address_element.nillable?).to be(true)
      expect(tags_element.nillable?).to be(true)
      expect(tags_element.singular?).to be(false)
    end

    it 'parses nillable on nested elements' do
      address_element = create_user_element.children.find { |c| c.name == 'address' }

      street_element = address_element.children.find { |c| c.name == 'street' }
      city_element = address_element.children.find { |c| c.name == 'city' }
      zip_element = address_element.children.find { |c| c.name == 'zipCode' }

      expect(street_element.nillable?).to be(true)
      expect(city_element.nillable?).to be(false)
      expect(zip_element.nillable?).to be(true)
    end
  end

  describe 'xsi:nil serialization' do
    let(:operation) { WSDL::Operation.new(operation_info, parser_result, http_mock) }

    def build_xml(operation, body)
      # These tests use incomplete data to focus on nillable serialization behavior
      apply_request(operation, body:, strict_schema: false)
      operation.to_xml
    end

    it 'serializes nil nillable simple elements with xsi:nil="true"' do
      xml = build_xml(operation, {
        CreateUser: {
          username: 'johndoe',
          email: nil,
          displayName: nil
        }
      })

      expect(xml).to include('xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"')
      expect(xml).to include('<ns0:email xsi:nil="true"/>')
      expect(xml).to include('<ns0:displayName xsi:nil="true"/>')
    end

    it 'serializes nil non-nillable elements as empty elements' do
      xml = build_xml(operation, {
        CreateUser: {
          username: 'johndoe',
          phoneNumber: nil,
          displayName: 'John'
        }
      })

      expect(xml).to include('<ns0:phoneNumber/>')
      expect(xml).not_to include('<ns0:phoneNumber xsi:nil')
    end

    it 'serializes nil nillable complex element with xsi:nil="true"' do
      xml = build_xml(operation, {
        CreateUser: {
          username: 'johndoe',
          displayName: 'John',
          address: nil
        }
      })

      expect(xml).to include('<ns0:address xsi:nil="true"/>')
    end

    it 'serializes nested nil values for nillable children with xsi:nil="true"' do
      xml = build_xml(operation, {
        CreateUser: {
          username: 'johndoe',
          displayName: 'John',
          address: {
            street: nil,
            city: 'New York',
            zipCode: nil
          }
        }
      })

      expect(xml).to include('<ns0:street xsi:nil="true"/>')
      expect(xml).to include('<ns0:zipCode xsi:nil="true"/>')
      expect(xml).to include('<ns0:city>New York</ns0:city>')
    end

    it 'serializes nil array entries with xsi:nil="true" for nillable arrays' do
      xml = build_xml(operation, {
        CreateUser: {
          username: 'johndoe',
          displayName: 'John',
          tags: ['ruby', nil, 'developer', nil]
        }
      })

      expect(xml.scan('<ns0:tags>ruby</ns0:tags>').length).to eq(1)
      expect(xml.scan('<ns0:tags>developer</ns0:tags>').length).to eq(1)
      expect(xml.scan('<ns0:tags xsi:nil="true"/>').length).to eq(2)
    end
  end
end
