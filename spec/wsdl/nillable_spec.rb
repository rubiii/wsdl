# frozen_string_literal: true

RSpec.describe 'Nillable elements' do
  let(:definition) { WSDL::Parser.parse(fixture('wsdl/nillable_elements'), http_mock) }
  let(:op_data) { definition.operation_data('UserService', 'UserServicePort', 'CreateUser') }
  let(:endpoint) { definition.endpoint('UserService', 'UserServicePort') }

  describe 'element nillable attribute parsing' do
    let(:body_parts) { op_data[:input][:body].map { |h| WSDL::Definition::ElementHash.new(h) } }
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
    let(:config) { WSDL::Config.new(strictness: WSDL::Strictness.off) }
    let(:operation) { WSDL::Operation.new(op_data, endpoint, http_mock, config:) }

    it 'serializes nil nillable simple elements with xsi:nil="true"' do
      operation.prepare do
        body do
          tag('CreateUser') do
            tag('username', 'johndoe')
            tag('email') do
              attribute('xsi:nil', 'true')
            end
            tag('displayName') { attribute('xsi:nil', 'true') }
          end
        end
      end
      xml = operation.to_xml

      expect(xml).to include('xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"')
      expect(xml).to include('<ns0:email xsi:nil="true"/>')
      expect(xml).to include('<ns0:displayName xsi:nil="true"/>')
    end

    it 'serializes nil non-nillable elements as empty elements' do
      operation.prepare do
        body do
          tag('CreateUser') do
            tag('username', 'johndoe')
            tag('phoneNumber')
            tag('displayName', 'John')
          end
        end
      end
      xml = operation.to_xml

      expect(xml).to include('<ns0:phoneNumber/>')
      expect(xml).not_to include('<ns0:phoneNumber xsi:nil')
    end

    it 'serializes nil nillable complex element with xsi:nil="true"' do
      operation.prepare do
        body do
          tag('CreateUser') do
            tag('username', 'johndoe')
            tag('displayName', 'John')
            tag('address') { attribute('xsi:nil', 'true') }
          end
        end
      end
      xml = operation.to_xml

      expect(xml).to include('<ns0:address xsi:nil="true"/>')
    end

    it 'serializes nested nil values for nillable children with xsi:nil="true"' do
      operation.prepare do
        body do
          tag('CreateUser') do
            tag('username', 'johndoe')
            tag('displayName', 'John')
            tag('address') do
              tag('street') do
                attribute('xsi:nil', 'true')
              end
              tag('city', 'New York')
              tag('zipCode') { attribute('xsi:nil', 'true') }
            end
          end
        end
      end
      xml = operation.to_xml

      expect(xml).to include('<ns0:street xsi:nil="true"/>')
      expect(xml).to include('<ns0:zipCode xsi:nil="true"/>')
      expect(xml).to include('<ns0:city>New York</ns0:city>')
    end

    it 'serializes nil array entries with xsi:nil="true" for nillable arrays' do
      operation.prepare do
        body do
          tag('CreateUser') do
            tag('username', 'johndoe')
            tag('displayName', 'John')
            tag('tags', 'ruby')
            tag('tags') { attribute('xsi:nil', 'true') }
            tag('tags', 'developer')
            tag('tags') { attribute('xsi:nil', 'true') }
          end
        end
      end
      xml = operation.to_xml

      expect(xml.scan('<ns0:tags>ruby</ns0:tags>').length).to eq(1)
      expect(xml.scan('<ns0:tags>developer</ns0:tags>').length).to eq(1)
      expect(xml.scan('<ns0:tags xsi:nil="true"/>').length).to eq(2)
    end
  end
end
